import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/agenda_provider.dart';
import 'assistant_remote.dart';
import 'pda_assistant_service.dart';
import 'voice_schedule_parser.dart';
import 'voice_service.dart';

/// Orquesta comandos de voz, diálogo multi-turno y agendado por voz.
class VoiceAssistantController {
  VoiceAssistantController._();

  static Future<void> runSession({AgendaProvider? provider, void Function(String partial)? onPartial}) async {
    await _refreshData(provider);
    await PdaAssistantService.instance.speak(
      'Te escucho. Puedes preguntar tu agenda, decir estado o próximo, '
      'o agendar por ejemplo: agenda reunión mañana a las tres de la tarde.',
    );

    final text = await VoiceService.instance.listenWithRetry(attempts: 2, onPartial: onPartial);
    if (text == null || text.trim().isEmpty) {
      await PdaAssistantService.instance.speak('No te escuché. Intenta de nuevo más cerca del micrófono.');
      return;
    }

    await process(text, provider: provider, onPartial: onPartial);
  }

  static Future<void> process(
    String raw, {
    AgendaProvider? provider,
    void Function(String partial)? onPartial,
  }) async {
    await _refreshData(provider);

    if (VoiceScheduleParser.isScheduleIntent(raw)) {
      await _handleSchedule(raw, provider: provider, onPartial: onPartial);
      return;
    }

    await PdaAssistantService.instance.processVoiceCommand(raw);
  }

  static Future<void> _handleSchedule(
    String raw, {
    AgendaProvider? provider,
    void Function(String partial)? onPartial,
  }) async {
    var draft = VoiceScheduleParser.parse(raw);
    final fmtDate = DateFormat('EEEE d MMMM', 'es');
    final fmtTime = DateFormat('HH:mm');

    // Completar título si falta
    if (!draft.hasTitle) {
      await PdaAssistantService.instance.speak('¿Cómo se llama la actividad?');
      final title = await VoiceService.instance.listenWithRetry(onPartial: onPartial);
      if (title == null || title.trim().length < 2) {
        await PdaAssistantService.instance.speak('No pude entender el nombre. Cancelado.');
        return;
      }
      draft.title = VoiceScheduleParser.parse('agendar $title').title ?? title.trim();
    }

    // Completar fecha/hora si falta
    if (!draft.hasStart) {
      await PdaAssistantService.instance.speak('¿Para qué día y a qué hora? Por ejemplo: mañana a las 10.');
      final when = await VoiceService.instance.listenWithRetry(onPartial: onPartial);
      if (when == null) {
        await PdaAssistantService.instance.speak('No entendí la fecha. Cancelado.');
        return;
      }
      final extra = VoiceScheduleParser.parse('agendar $when');
      draft.startsAt = extra.startsAt ?? draft.startsAt;
      draft.duration = extra.duration;
    }

    // Empresa
    final companies = provider?.companies ?? await AssistantRemote.fetchCompanies();
    if (companies.isEmpty) {
      await PdaAssistantService.instance.speak('No hay empresas configuradas. Agrega una desde la web.');
      return;
    }

    Company? company = _matchCompany(draft.companyHint, companies);
    if (company == null && companies.length == 1) {
      company = companies.first;
    } else if (company == null) {
      final names = companies.map((c) => c.name).join(', ');
      await PdaAssistantService.instance.speak('¿Para qué empresa? Opciones: $names');
      final answer = await VoiceService.instance.listenWithRetry(onPartial: onPartial);
      company = answer != null ? _matchCompany(answer, companies) : null;
      company ??= companies.first;
    }

    final start = draft.startsAt!;
    final end = draft.endsAt!;
    final summary =
        '${draft.title}, ${fmtDate.format(start)} a las ${fmtTime.format(start)}, con ${company.name}';

    await PdaAssistantService.instance.speak('Voy a agendar: $summary. ¿Confirmas? Di sí o no.');
    final confirmed = await VoiceService.instance.confirmYesNo();
    if (confirmed != true) {
      await PdaAssistantService.instance.speak(confirmed == false ? 'Cancelado.' : 'No te entendí. Cancelado.');
      return;
    }

    final commitment = Commitment(
      id: 0,
      companyId: company.id,
      title: draft.title!,
      startsAt: start,
      endsAt: end,
      company: company,
    );

    String? error;
    if (provider != null) {
      error = await provider.saveCommitment(commitment);
    } else {
      error = await AssistantRemote.createCommitment(commitment);
    }

    if (error != null) {
      await PdaAssistantService.instance.speak('No pude guardarlo: $error');
      return;
    }

    await PdaAssistantService.instance.setDayMode(DayMode.active);
    await PdaAssistantService.instance.speak(
      'Listo. Agendé ${draft.title} para el ${fmtDate.format(start)} a las ${fmtTime.format(start)}.',
    );
    await _refreshData(provider);
  }

  static Company? _matchCompany(String? hint, List<Company> companies) {
    if (hint == null || hint.isEmpty) return null;
    final h = hint.toLowerCase().replaceAll(' ', '');

    for (final c in companies) {
      final name = c.name.toLowerCase().replaceAll(' ', '');
      final slug = c.slug.toLowerCase();
      if (name.contains(h) || h.contains(name) || slug.contains(h) || h.contains(slug)) {
        return c;
      }
      if (h.contains('lc') && slug.contains('lcdesign')) return c;
      if (h.contains('inter') && slug.contains('intervereda')) return c;
    }
    return null;
  }

  static Future<void> _refreshData(AgendaProvider? provider) async {
    if (provider != null) {
      final map = <int, Commitment>{};
      for (final e in provider.calendarEvents) {
        map[e.id] = e;
      }
      for (final e in provider.upcoming) {
        map[e.id] = e;
      }
      PdaAssistantService.instance.updateCommitments(map.values.toList());
      PdaAssistantService.instance.userName = provider.user?.name;
      await PdaAssistantService.instance.evaluateDayModeFromEvents(provider.todayAgenda());
      return;
    }

    final all = await AssistantRemote.fetchActiveCommitments();
    PdaAssistantService.instance.updateCommitments(all);
    final today = await AssistantRemote.fetchTodayCommitments();
    await PdaAssistantService.instance.evaluateDayModeFromEvents(today);
  }
}

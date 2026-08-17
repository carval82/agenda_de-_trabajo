/// Borrador de compromiso extraído de voz.
class VoiceScheduleDraft {
  VoiceScheduleDraft({
    this.title,
    this.startsAt,
    this.duration = const Duration(hours: 1),
    this.companyHint,
  });

  String? title;
  DateTime? startsAt;
  Duration duration;
  String? companyHint;

  DateTime? get endsAt => startsAt?.add(duration);

  bool get hasTitle => title != null && title!.trim().length >= 2;
  bool get hasStart => startsAt != null;

  String describe(DateFormatFn formatDate, DateFormatFn formatTime) {
    final parts = <String>[];
    if (hasTitle) parts.add(title!);
    if (hasStart) {
      parts.add('${formatDate(startsAt!)} a las ${formatTime(startsAt!)}');
    }
    if (companyHint != null) parts.add('con $companyHint');
    return parts.join(', ');
  }
}

typedef DateFormatFn = String Function(DateTime);

/// Interpreta frases en español para agendar compromisos.
class VoiceScheduleParser {
  VoiceScheduleParser._();

  static const _scheduleVerbs = [
    'agendar',
    'agenda',
    'agrega',
    'agregar',
    'añadir',
    'anadir',
    'crear',
    'programar',
    'programa',
    'apuntar',
    'apunta',
    'nueva cita',
    'nuevo compromiso',
    'nueva actividad',
    'recordar',
  ];

  static const _weekdays = {
    'lunes': DateTime.monday,
    'martes': DateTime.tuesday,
    'miércoles': DateTime.wednesday,
    'miercoles': DateTime.wednesday,
    'jueves': DateTime.thursday,
    'viernes': DateTime.friday,
    'sábado': DateTime.saturday,
    'sabado': DateTime.saturday,
    'domingo': DateTime.sunday,
  };

  static bool isScheduleIntent(String text) {
    final t = _norm(text);
    return _scheduleVerbs.any((v) => t.contains(v));
  }

  static VoiceScheduleDraft parse(String raw) {
    var text = _norm(raw);
    final draft = VoiceScheduleDraft();

    // Duración: "por 2 horas", "duración 30 minutos"
    draft.duration = _parseDuration(text) ?? const Duration(hours: 1);
    text = _stripDuration(text);

    // Empresa: "con lc design", "para intervereda", "en lcdesign"
    draft.companyHint = _parseCompanyHint(text);
    text = _stripCompanyHint(text);

    // Fecha + hora
    final (date, timeText) = _parseDateTime(text);
    draft.startsAt = _combineDateTime(date, timeText);
    text = _stripDateTime(text);

    // Título: lo que queda tras quitar verbo de agendar
    draft.title = _parseTitle(text);

    return draft;
  }

  static String _norm(String s) {
    return s
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  static Duration? _parseDuration(String text) {
    final h = RegExp(r'(?:por|duracion|durante)\s+(\d+)\s*hora').firstMatch(text);
    if (h != null) return Duration(hours: int.parse(h.group(1)!));

    final m = RegExp(r'(?:por|duracion|durante)\s+(\d+)\s*min').firstMatch(text);
    if (m != null) return Duration(minutes: int.parse(m.group(1)!));

    return null;
  }

  static String _stripDuration(String text) {
    return text
        .replaceAll(RegExp(r'(?:por|duracion|durante)\s+\d+\s*(?:hora|horas|min(?:uto)?s?)'), '')
        .trim();
  }

  static String? _parseCompanyHint(String text) {
    final patterns = [
      RegExp(r'(?:con|para|en)\s+([a-z0-9\s\.]+?)(?:\s+(?:a las|el |hoy|manana|lunes|martes|miercoles|jueves|viernes|sabado|domingo)|$)'),
      RegExp(r'(?:con|para|en)\s+(lc\s*design|intervereda(?:net)?|inter\s*vereda)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final hint = m.group(1)!.trim();
        if (hint.length >= 2 && !_isTimeFragment(hint)) return hint;
      }
    }
    return null;
  }

  static bool _isTimeFragment(String s) {
    return RegExp(r'^\d').hasMatch(s) || s.contains(' las ');
  }

  static String _stripCompanyHint(String text) {
    return text
        .replaceAll(RegExp(r'(?:con|para|en)\s+(?:lc\s*design|intervereda(?:net)?|inter\s*vereda|[a-z0-9\s\.]+?)(?=\s+(?:a las|el |hoy|manana|lunes|martes|miercoles|jueves|viernes|sabado|domingo)|$)'), '')
        .trim();
  }

  static (DateTime?, String?) _parseDateTime(String text) {
    final now = DateTime.now();
    DateTime? date;

    if (text.contains('pasado manana')) {
      date = DateTime(now.year, now.month, now.day).add(const Duration(days: 2));
    } else if (text.contains('manana')) {
      date = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    } else if (text.contains('hoy')) {
      date = DateTime(now.year, now.month, now.day);
    }

    for (final entry in _weekdays.entries) {
      if (text.contains('el ${entry.key}') || text.contains('este ${entry.key}') || text.contains(entry.key)) {
        date = _nextWeekday(entry.value);
        break;
      }
    }

    // "el 20", "el dia 20"
    final dayNum = RegExp(r'(?:el|dia)\s+(\d{1,2})(?:\s+de|\s+del|\s|$)').firstMatch(text);
    if (dayNum != null) {
      final d = int.parse(dayNum.group(1)!);
      var candidate = DateTime(now.year, now.month, d);
      if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
        candidate = DateTime(now.year, now.month + 1, d);
      }
      date = candidate;
    }

    String? timeText;
    final timePatterns = [
      RegExp(r'a las (\d{1,2})(?::(\d{2}))?\s*(?:de la )?(manana|tarde|noche|pm|am)?'),
      RegExp(r'(?:a|alas)\s*(\d{1,2})(?::(\d{2}))?\s*(?:horas?)?\s*(?:de la )?(manana|tarde|noche|pm|am)?'),
      RegExp(r'(\d{1,2}):(\d{2})'),
    ];

    for (final p in timePatterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        timeText = m.group(0);
        break;
      }
    }

    return (date, timeText);
  }

  static DateTime _nextWeekday(int weekday) {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day);
    while (d.weekday != weekday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  static DateTime? _combineDateTime(DateTime? date, String? timeText) {
    if (timeText == null && date == null) return null;

    final base = date ?? DateTime.now();
    if (timeText == null) {
      // Solo fecha → 9:00 por defecto si es futuro, o próxima hora redondeada
      final now = DateTime.now();
      if (base.year == now.year && base.month == now.month && base.day == now.day) {
        final next = now.add(const Duration(hours: 1));
        return DateTime(base.year, base.month, base.day, next.hour, 0);
      }
      return DateTime(base.year, base.month, base.day, 9, 0);
    }

    final m = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(?:de la )?(manana|tarde|noche|pm|am)?').firstMatch(timeText);
    if (m == null) return DateTime(base.year, base.month, base.day, 9, 0);

    var hour = int.parse(m.group(1)!);
    final minute = int.tryParse(m.group(2) ?? '0') ?? 0;
    final period = m.group(3);

    if (period == 'tarde' || period == 'noche' || period == 'pm') {
      if (hour < 12) hour += 12;
    } else if (period == 'manana' || period == 'am') {
      if (hour == 12) hour = 0;
    } else if (hour <= 7 && period == null) {
      // "a las 3" sin periodo → asumir tarde si <=7
      hour += 12;
    }

    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  static String _stripDateTime(String text) {
    var t = text;
    t = t.replaceAll('pasado manana', '');
    t = t.replaceAll('manana', '');
    t = t.replaceAll('hoy', '');
    for (final day in _weekdays.keys) {
      t = t.replaceAll('el $day', '');
      t = t.replaceAll('este $day', '');
      t = t.replaceAll(day, '');
    }
    t = t.replaceAll(RegExp(r'(?:el|dia)\s+\d{1,2}'), '');
    t = t.replaceAll(RegExp(r'a las \d{1,2}(?::\d{2})?\s*(?:de la )?(?:manana|tarde|noche|pm|am)?'), '');
    t = t.replaceAll(RegExp(r'(?:a|alas)\s*\d{1,2}(?::\d{2})?\s*(?:horas?)?\s*(?:de la )?(?:manana|tarde|noche|pm|am)?'), '');
    t = t.replaceAll(RegExp(r'\d{1,2}:\d{2}'), '');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? _parseTitle(String text) {
    var t = text;
    for (final verb in _scheduleVerbs) {
      if (t.startsWith('$verb ')) {
        t = t.substring(verb.length + 1);
      }
      t = t.replaceAll(verb, '');
    }
    t = t.replaceAll(RegExp(r'^(una|un|la|el|nueva|nuevo|cita|compromiso|actividad)\s+'), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (t.length < 2) return null;
    if (RegExp(r'^\d').hasMatch(t)) return null;
    return _capitalize(t);
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

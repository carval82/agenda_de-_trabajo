class RecurringEvent {
  RecurringEvent({
    required this.id,
    required this.companyId,
    required this.title,
    required this.recurrence,
    required this.startsOn,
    this.description,
    this.clientName,
    this.category = 'general',
    this.amount,
    this.dayOfMonth,
    this.weekday,
    this.month,
    this.timeHour = 9,
    this.timeMinute = 0,
    this.durationMinutes = 30,
    this.reminderMinutes = const [1440, 60, 15],
    this.endsOn,
    this.isActive = true,
  });

  final int id;
  final int companyId;
  final String title;
  final String recurrence;
  final DateTime startsOn;
  final String? description;
  final String? clientName;
  final String category;
  final double? amount;
  final int? dayOfMonth;
  final int? weekday;
  final int? month;
  final int timeHour;
  final int timeMinute;
  final int durationMinutes;
  final List<int> reminderMinutes;
  final DateTime? endsOn;
  final bool isActive;

  String get recurrenceLabel {
    switch (recurrence) {
      case 'daily':
        return 'Cada día';
      case 'weekly':
        return 'Cada semana';
      case 'monthly':
        return 'Cada mes';
      case 'yearly':
        return 'Cada año';
      default:
        return recurrence;
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'payment':
        return 'Pago';
      case 'invoice':
        return 'Factura';
      case 'reminder':
        return 'Recordatorio';
      default:
        return 'General';
    }
  }

  String get scheduleSummary {
    final time = '${timeHour.toString().padLeft(2, '0')}:${timeMinute.toString().padLeft(2, '0')}';
    switch (recurrence) {
      case 'daily':
        return 'Todos los días a las $time';
      case 'weekly':
        const days = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
        final d = weekday != null && weekday! >= 1 && weekday! <= 7 ? days[weekday!] : 'semana';
        return 'Cada $d a las $time';
      case 'monthly':
        return 'Día ${dayOfMonth ?? startsOn.day} de cada mes a las $time';
      case 'yearly':
        return 'Cada año a las $time';
      default:
        return recurrenceLabel;
    }
  }

  factory RecurringEvent.fromJson(Map<String, dynamic> json) {
    return RecurringEvent(
      id: json['id'] as int,
      companyId: json['company_id'] as int,
      title: json['title'] as String,
      recurrence: json['recurrence'] as String,
      startsOn: DateTime.parse(json['starts_on'] as String),
      description: json['description'] as String?,
      clientName: json['client_name'] as String?,
      category: json['category'] as String? ?? 'general',
      amount: json['amount'] != null ? double.tryParse(json['amount'].toString()) : null,
      dayOfMonth: json['day_of_month'] as int?,
      weekday: json['weekday'] as int?,
      month: json['month'] as int?,
      timeHour: json['time_hour'] as int? ?? 9,
      timeMinute: json['time_minute'] as int? ?? 0,
      durationMinutes: json['duration_minutes'] as int? ?? 30,
      reminderMinutes: (json['reminder_minutes'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [1440, 60, 15],
      endsOn: json['ends_on'] != null ? DateTime.parse(json['ends_on'] as String) : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'title': title,
      'description': description,
      'client_name': clientName,
      'category': category,
      if (amount != null) 'amount': amount,
      'recurrence': recurrence,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (weekday != null) 'weekday': weekday,
      if (month != null) 'month': month,
      'time_hour': timeHour,
      'time_minute': timeMinute,
      'duration_minutes': durationMinutes,
      'reminder_minutes': reminderMinutes,
      'starts_on': startsOn.toIso8601String().split('T').first,
      if (endsOn != null) 'ends_on': endsOn!.toIso8601String().split('T').first,
      'is_active': isActive,
    };
  }
}

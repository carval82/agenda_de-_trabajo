class Company {
  Company({
    required this.id,
    required this.name,
    required this.slug,
    required this.type,
    required this.color,
    this.tagline,
  });

  final int id;
  final String name;
  final String slug;
  final String type;
  final String color;
  final String? tagline;

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      type: json['type'] as String,
      color: json['color'] as String? ?? '#2563eb',
      tagline: json['tagline'] as String?,
    );
  }
}

class Commitment {
  Commitment({
    required this.id,
    required this.companyId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.description,
    this.location,
    this.clientName,
    this.priority = 'medium',
    this.status = 'scheduled',
    this.reminderMinutes = const [15, 60],
    this.company,
  });

  final int id;
  final int companyId;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? description;
  final String? location;
  final String? clientName;
  final String priority;
  final String status;
  final List<int> reminderMinutes;
  final Company? company;

  factory Commitment.fromJson(Map<String, dynamic> json) {
    return Commitment(
      id: json['id'] as int,
      companyId: json['company_id'] as int,
      title: json['title'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      description: json['description'] as String?,
      location: json['location'] as String?,
      clientName: json['client_name'] as String?,
      priority: json['priority'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'scheduled',
      reminderMinutes: (json['reminder_minutes'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [15, 60],
      company: json['company'] != null
          ? Company.fromJson(json['company'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'title': title,
      'description': description,
      'location': location,
      'client_name': clientName,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'priority': priority,
      'status': status,
      'reminder_minutes': reminderMinutes,
    };
  }
}

class CourtModel {
  final String id;
  final String name;
  final String sportId;
  final String? surfaceType;
  final bool isCovered;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Schedule config
  final int slotDurationMinutes;
  final String openingTime; // "HH:mm"
  final String closingTime; // "HH:mm"
  final List<int> operatingDays; // [0=Sun, 1=Mon, ..., 6=Sat]

  const CourtModel({
    required this.id,
    required this.name,
    required this.sportId,
    this.surfaceType,
    this.isCovered = false,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.slotDurationMinutes = 60,
    this.openingTime = '07:00',
    this.closingTime = '22:00',
    this.operatingDays = const [0, 1, 2, 3, 4, 5, 6],
  });

  /// Whether this court operates on the given day (0=Sun, 6=Sat)
  bool operatesOn(int dayOfWeek) => operatingDays.contains(dayOfWeek);

  String get surfaceLabel {
    if (surfaceType == null) return 'N/A';
    return surfaceType!
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String _normalizeTime(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    return CourtModel(
      id: json['id'] as String,
      name: json['name'] as String,
      sportId: json['sport_id'] as String,
      surfaceType: json['surface_type'] as String?,
      isCovered: json['is_covered'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      slotDurationMinutes: json['slot_duration_minutes'] as int? ?? 60,
      openingTime: _normalizeTime(json['opening_time'] as String? ?? '07:00'),
      closingTime: _normalizeTime(json['closing_time'] as String? ?? '22:00'),
      operatingDays: (json['operating_days'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [0, 1, 2, 3, 4, 5, 6],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sport_id': sportId,
      'surface_type': surfaceType,
      'is_covered': isCovered,
      'is_active': isActive,
      'notes': notes,
      'slot_duration_minutes': slotDurationMinutes,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'operating_days': operatingDays,
    };
  }
}

import 'package:equatable/equatable.dart';

enum SeriesRepeatType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
}

enum SeriesEndType {
  never,
  afterOccurrences,
  onDate,
}

class CalendarEventSeriesModel extends Equatable {
  final String id;
  final String userId;
  final SeriesRepeatType repeatType;
  final int repeatInterval; // Every X days/weeks/months/years
  final List<int> repeatDaysOfWeek; // For weekly repeats, 1-7 (Monday-Sunday)
  final SeriesEndType endType;
  final int? occurrences; // For afterOccurrences end type
  final DateTime? endDate; // For onDate end type
  final String templateEventId; // ID of the first event that serves as template

  const CalendarEventSeriesModel({
    required this.id,
    required this.userId,
    required this.repeatType,
    required this.repeatInterval,
    this.repeatDaysOfWeek = const [],
    required this.endType,
    this.occurrences,
    this.endDate,
    required this.templateEventId,
  });

  // Factory for JSON
  factory CalendarEventSeriesModel.fromJson(Map<String, dynamic> json) {
    return CalendarEventSeriesModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      repeatType: SeriesRepeatType.values[json['repeat_type'] as int],
      repeatInterval: json['repeat_interval'] as int,
      repeatDaysOfWeek: json['repeat_days_of_week'] != null
          ? List<int>.from(json['repeat_days_of_week'] as List)
          : [],
      endType: SeriesEndType.values[json['end_type'] as int],
      occurrences: json['occurrences'] as int?,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      templateEventId: json['template_event_id'] as String,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'repeat_type': repeatType.index,
      'repeat_interval': repeatInterval,
      'repeat_days_of_week': repeatDaysOfWeek,
      'end_type': endType.index,
      'occurrences': occurrences,
      'end_date': endDate?.toIso8601String(),
      'template_event_id': templateEventId,
    };
  }

  // Copy with method
  CalendarEventSeriesModel copyWith({
    String? id,
    String? userId,
    SeriesRepeatType? repeatType,
    int? repeatInterval,
    List<int>? repeatDaysOfWeek,
    SeriesEndType? endType,
    int? occurrences,
    DateTime? endDate,
    String? templateEventId,
  }) {
    return CalendarEventSeriesModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      repeatType: repeatType ?? this.repeatType,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatDaysOfWeek: repeatDaysOfWeek ?? this.repeatDaysOfWeek,
      endType: endType ?? this.endType,
      occurrences: occurrences ?? this.occurrences,
      endDate: endDate ?? this.endDate,
      templateEventId: templateEventId ?? this.templateEventId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        repeatType,
        repeatInterval,
        repeatDaysOfWeek,
        endType,
        occurrences,
        endDate,
        templateEventId,
      ];
}

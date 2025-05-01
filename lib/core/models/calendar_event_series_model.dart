import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'calendar_event_series_model.g.dart';

@HiveType(typeId: 11)
enum SeriesRepeatType {
  @HiveField(0)
  none,
  @HiveField(1)
  daily,
  @HiveField(2)
  weekly,
  @HiveField(3)
  monthly,
  @HiveField(4)
  yearly,
}

@HiveType(typeId: 12)
enum SeriesEndType {
  @HiveField(0)
  never,
  @HiveField(1)
  afterOccurrences,
  @HiveField(2)
  onDate,
}

@HiveType(typeId: 3)
class CalendarEventSeriesModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String userId;
  @HiveField(2)
  final SeriesRepeatType repeatType;
  @HiveField(3)
  final int repeatInterval; // Every X days/weeks/months/years
  @HiveField(4)
  final List<int> repeatDaysOfWeek; // For weekly repeats, 1-7 (Monday-Sunday)
  @HiveField(5)
  final SeriesEndType endType;
  @HiveField(6)
  final int? occurrences; // For afterOccurrences end type
  @HiveField(7)
  final DateTime? endDate; // For onDate end type
  @HiveField(8)
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
      repeatDaysOfWeek: json['repeat_days_of_week'] != null ? List<int>.from(json['repeat_days_of_week'] as List) : [],
      endType: SeriesEndType.values[json['end_type'] as int],
      occurrences: json['occurrences'] as int?,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
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

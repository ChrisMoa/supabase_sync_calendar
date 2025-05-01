import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:supabase_sync_calendar/core/utils/supabase_utils.dart';

part 'calendar_event_model.g.dart';

@HiveType(typeId: 2)
class CalendarEventModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String description;
  @HiveField(3)
  final DateTime start;
  @HiveField(4)
  final DateTime end;
  @HiveField(5)
  final int colorValue;
  @HiveField(6)
  final String userId;
  @HiveField(7)
  final bool wholeDay;
  @HiveField(8)
  final String calendarId; // Now references the calendar table
  @HiveField(9)
  final DateTime? reminder;
  @HiveField(10)
  final List<String> appendixes;
  @HiveField(11)
  final bool isExternalReadOnly; // Added to mark external sync events as read-only
  @HiveField(12)
  final String? seriesId;

  Color get color => Color(colorValue);

  CalendarEventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    required this.colorValue,
    required this.userId,
    required this.calendarId,
    this.wholeDay = false,
    this.reminder,
    this.appendixes = const [],
    this.isExternalReadOnly = false,
    this.seriesId,
  });

  CalendarEventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? start,
    DateTime? end,
    int? colorValue,
    String? userId,
    bool? wholeDay,
    String? calendarId,
    DateTime? reminder,
    List<String>? appendixes,
    bool? isExternalReadOnly,
    String? seriesId,
  }) {
    return CalendarEventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      start: start ?? this.start,
      end: end ?? this.end,
      colorValue: colorValue ?? this.colorValue,
      userId: userId ?? this.userId,
      wholeDay: wholeDay ?? this.wholeDay,
      calendarId: calendarId ?? this.calendarId,
      reminder: reminder ?? this.reminder,
      appendixes: appendixes ?? this.appendixes,
      isExternalReadOnly: isExternalReadOnly ?? this.isExternalReadOnly,
      seriesId: seriesId ?? this.seriesId,
    );
  }

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    int colorValue = json[SupabaseUtils.colColor] as int;
    colorValue = colorValue | 0xFF000000;

    return CalendarEventModel(
      id: json[SupabaseUtils.colId] as String,
      title: json[SupabaseUtils.colTitle] as String? ?? 'Untitled Event',
      description: json[SupabaseUtils.colDescription] as String? ?? '',
      start: DateTime.parse(json[SupabaseUtils.colStartTime] as String),
      end: DateTime.parse(json[SupabaseUtils.colEndTime] as String),
      colorValue: colorValue,
      userId: json[SupabaseUtils.colUserId] as String,
      wholeDay: json['whole_day'] as bool? ?? false,
      calendarId: json['calendar_id'] as String? ?? 'default',
      reminder: json['reminder'] != null ? DateTime.parse(json['reminder'] as String) : null,
      appendixes: json['appendixes'] != null ? List<String>.from(json['appendixes'] as List) : const [],
      isExternalReadOnly: json['is_external_read_only'] as bool? ?? false,
      seriesId: json['series_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      SupabaseUtils.colId: id,
      SupabaseUtils.colTitle: title,
      SupabaseUtils.colDescription: description,
      SupabaseUtils.colStartTime: start.toIso8601String(),
      SupabaseUtils.colEndTime: end.toIso8601String(),
      SupabaseUtils.colColor: colorValue & 0xFFFFFF,
      SupabaseUtils.colUserId: userId,
      'whole_day': wholeDay,
      'calendar_id': calendarId,
      'reminder': reminder?.toIso8601String(),
      'appendixes': appendixes,
      'is_external_read_only': isExternalReadOnly,
      'series_id': seriesId,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        start,
        end,
        colorValue,
        userId,
        wholeDay,
        calendarId,
        reminder,
        appendixes,
        isExternalReadOnly,
        seriesId,
      ];
}

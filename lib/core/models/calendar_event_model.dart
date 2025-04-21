import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:supabase_sync_calendar/core/utils/supabase_utils.dart';

class CalendarEventModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
  final Color color;
  final String userId;

  const CalendarEventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    required this.color,
    required this.userId,
  });

  CalendarEventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? start,
    DateTime? end,
    Color? color,
    String? userId,
  }) {
    return CalendarEventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      start: start ?? this.start,
      end: end ?? this.end,
      color: color ?? this.color,
      userId: userId ?? this.userId,
    );
  }

  // Convert from Supabase Map to CalendarEventModel
  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    int colorValue = json[SupabaseUtils.colColor] as int;
    // Add back the alpha channel (fully opaque)
    colorValue = colorValue | 0xFF000000;

    return CalendarEventModel(
      id: json[SupabaseUtils.colId] as String,
      title: json[SupabaseUtils.colTitle] as String,
      description: json[SupabaseUtils.colDescription] as String,
      start: DateTime.parse(json[SupabaseUtils.colStartTime] as String),
      end: DateTime.parse(json[SupabaseUtils.colEndTime] as String),
      color: Color(colorValue),
      userId: json[SupabaseUtils.colUserId] as String,
    );
  }
  // Convert to Supabase Map from CalendarEventModel
  Map<String, dynamic> toJson() {
    return {
      SupabaseUtils.colId: id,
      SupabaseUtils.colTitle: title,
      SupabaseUtils.colDescription: description,
      SupabaseUtils.colStartTime: start.toIso8601String(),
      SupabaseUtils.colEndTime: end.toIso8601String(),
      SupabaseUtils.colColor:
          color.value & 0xFFFFFF, // Remove alpha channel and keep only RGB
      SupabaseUtils.colUserId: userId,
    };
  }

  @override
  List<Object?> get props =>
      [id, title, description, start, end, color, userId];
}

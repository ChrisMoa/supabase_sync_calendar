// lib/core/models/calendar_model.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum CalendarType {
  local, // Default calendar created by the user
  webdav, // WebDAV synced calendar
  device // Device calendar
}

class CalendarModel extends Equatable {
  final String id;
  final String name;
  final Color color;
  final String userId;
  final CalendarType type;
  final bool isDefault;
  final String? syncUrl; // For WebDAV calendars
  final String? deviceCalendarId; // For device calendars

  const CalendarModel({
    required this.id,
    required this.name,
    required this.color,
    required this.userId,
    required this.type,
    this.isDefault = false,
    this.syncUrl,
    this.deviceCalendarId,
  });

  // Copy with
  CalendarModel copyWith({
    String? id,
    String? name,
    Color? color,
    String? userId,
    CalendarType? type,
    bool? isDefault,
    String? syncUrl,
    String? deviceCalendarId,
  }) {
    return CalendarModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      syncUrl: syncUrl ?? this.syncUrl,
      deviceCalendarId: deviceCalendarId ?? this.deviceCalendarId,
    );
  }

  // From JSON
  factory CalendarModel.fromJson(Map<String, dynamic> json) {
    return CalendarModel(
      id: json['id'] as String,
      name: json['name'] as String,
      color: Color(json['color'] as int),
      userId: json['user_id'] as String,
      type: CalendarType.values[json['type'] as int],
      isDefault: json['is_default'] as bool? ?? false,
      syncUrl: json['sync_url'] as String?,
      deviceCalendarId: json['device_calendar_id'] as String?,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.value & 0xFFFFFF,
      'user_id': userId,
      'type': type.index,
      'is_default': isDefault,
      'sync_url': syncUrl,
      'device_calendar_id': deviceCalendarId,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        color,
        userId,
        type,
        isDefault,
        syncUrl,
        deviceCalendarId,
      ];
}

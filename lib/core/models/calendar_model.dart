import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'calendar_model.g.dart';

enum CalendarType { local, webdav, device }

@HiveType(typeId: 1)
class CalendarModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int colorValue; // Store color as int, not Color

  @HiveField(3)
  final String userId;

  @HiveField(4)
  @HiveType(typeId: 10) // Assign a unique typeId for the enum
  final CalendarType type;

  @HiveField(5)
  final bool isDefault;

  @HiveField(6)
  final String? syncUrl;

  @HiveField(7)
  final String? deviceCalendarId;

  @HiveField(8)
  final DateTime lastSynced;

  @HiveField(9)
  final bool isSynced;

  // Computed property (not stored in Hive)
  Color get color => Color(colorValue);

  // Constructor now takes colorValue directly
  CalendarModel({
    required this.id,
    required this.name,
    required this.colorValue, // Changed from color
    required this.userId,
    required this.type,
    this.isDefault = false,
    this.syncUrl,
    this.deviceCalendarId,
    DateTime? lastSynced,
    this.isSynced = false,
  }) : // Removed colorValue initializer
        lastSynced = lastSynced ?? DateTime.now();

  @override
  List<Object?> get props => [
        id,
        name,
        colorValue,
        userId,
        type,
        isDefault,
        syncUrl,
        deviceCalendarId,
        lastSynced,
        isSynced,
      ];

  CalendarModel copyWith({
    String? id,
    String? name,
    int? colorValue, // Changed from Color?
    String? userId,
    CalendarType? type,
    bool? isDefault,
    String? syncUrl,
    String? deviceCalendarId,
    DateTime? lastSynced,
    bool? isSynced,
  }) {
    return CalendarModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue, // Changed from color
      userId: userId ?? this.userId,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      syncUrl: syncUrl ?? this.syncUrl,
      deviceCalendarId: deviceCalendarId ?? this.deviceCalendarId,
      lastSynced: lastSynced ?? this.lastSynced,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  // Factory constructor for creating a new CalendarModel instance from a map.
  factory CalendarModel.fromJson(Map<String, dynamic> json) {
    // Default color if none provided or it's null (blue)
    final int defaultColorValue = Colors.blue.value;

    // Try to parse colorValue safely - check both 'colorValue' and 'color' fields
    int colorValue;
    try {
      // First try to get 'colorValue', then fall back to 'color' for compatibility
      colorValue = json['colorValue'] as int? ?? json['color'] as int? ?? defaultColorValue;
    } catch (e) {
      // Handle the case where colorValue can't be cast to int
      debugPrint('Error parsing colorValue: $e, using default');
      colorValue = defaultColorValue;
    }

    // Parse calendar type safely
    CalendarType calendarType;
    try {
      final typeIndex = json['type'] as int? ?? 0;
      calendarType = CalendarType.values[typeIndex];
    } catch (e) {
      debugPrint('Error parsing calendar type: $e, using default');
      calendarType = CalendarType.local;
    }

    // Check for both camelCase and snake_case versions of fields to support both formats
    return CalendarModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Calendar',
      colorValue: colorValue,
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '', // Check both formats
      type: calendarType,
      isDefault: json['isDefault'] as bool? ?? json['is_default'] as bool? ?? false, // Check both formats
      syncUrl: json['syncUrl'] as String? ?? json['sync_url'] as String?, // Check both formats
      deviceCalendarId: json['deviceCalendarId'] as String? ?? json['device_calendar_id'] as String?, // Check both formats
      lastSynced: json['lastSynced'] != null ? DateTime.parse(json['lastSynced'] as String) : (json['last_synced'] != null ? DateTime.parse(json['last_synced'] as String) : DateTime.now()),
      isSynced: json['isSynced'] as bool? ?? json['is_synced'] as bool? ?? false, // Check both formats
    );
  }

  // Method for converting a CalendarModel instance into a map.
  Map<String, dynamic> toJson() {
    // Create map with compatible field names for Supabase
    final Map<String, dynamic> json = {
      'id': id,
      'name': name,
      'color': colorValue, // Use 'color' instead of 'colorValue' for compatibility
      'user_id': userId, // Use 'user_id' instead of 'userId' for Supabase compatibility
      'type': type.index,
      'is_default': isDefault, // Add is_default to sync this field with Supabase
    };

    // Only include optional fields if they're supported by the Supabase schema
    // These fields might not exist in the Supabase database
    if (syncUrl != null) {
      json['sync_url'] = syncUrl; // Use snake_case for Supabase
    }

    if (deviceCalendarId != null) {
      json['device_calendar_id'] = deviceCalendarId; // Use snake_case for Supabase
    }

    return json;
  }
}

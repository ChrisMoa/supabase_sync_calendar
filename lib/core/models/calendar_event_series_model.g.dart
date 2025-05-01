// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_event_series_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalendarEventSeriesModelAdapter
    extends TypeAdapter<CalendarEventSeriesModel> {
  @override
  final int typeId = 3;

  @override
  CalendarEventSeriesModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalendarEventSeriesModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      repeatType: fields[2] as SeriesRepeatType,
      repeatInterval: fields[3] as int,
      repeatDaysOfWeek: (fields[4] as List).cast<int>(),
      endType: fields[5] as SeriesEndType,
      occurrences: fields[6] as int?,
      endDate: fields[7] as DateTime?,
      templateEventId: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CalendarEventSeriesModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.repeatType)
      ..writeByte(3)
      ..write(obj.repeatInterval)
      ..writeByte(4)
      ..write(obj.repeatDaysOfWeek)
      ..writeByte(5)
      ..write(obj.endType)
      ..writeByte(6)
      ..write(obj.occurrences)
      ..writeByte(7)
      ..write(obj.endDate)
      ..writeByte(8)
      ..write(obj.templateEventId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEventSeriesModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SeriesRepeatTypeAdapter extends TypeAdapter<SeriesRepeatType> {
  @override
  final int typeId = 11;

  @override
  SeriesRepeatType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SeriesRepeatType.none;
      case 1:
        return SeriesRepeatType.daily;
      case 2:
        return SeriesRepeatType.weekly;
      case 3:
        return SeriesRepeatType.monthly;
      case 4:
        return SeriesRepeatType.yearly;
      default:
        return SeriesRepeatType.none;
    }
  }

  @override
  void write(BinaryWriter writer, SeriesRepeatType obj) {
    switch (obj) {
      case SeriesRepeatType.none:
        writer.writeByte(0);
        break;
      case SeriesRepeatType.daily:
        writer.writeByte(1);
        break;
      case SeriesRepeatType.weekly:
        writer.writeByte(2);
        break;
      case SeriesRepeatType.monthly:
        writer.writeByte(3);
        break;
      case SeriesRepeatType.yearly:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeriesRepeatTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SeriesEndTypeAdapter extends TypeAdapter<SeriesEndType> {
  @override
  final int typeId = 12;

  @override
  SeriesEndType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SeriesEndType.never;
      case 1:
        return SeriesEndType.afterOccurrences;
      case 2:
        return SeriesEndType.onDate;
      default:
        return SeriesEndType.never;
    }
  }

  @override
  void write(BinaryWriter writer, SeriesEndType obj) {
    switch (obj) {
      case SeriesEndType.never:
        writer.writeByte(0);
        break;
      case SeriesEndType.afterOccurrences:
        writer.writeByte(1);
        break;
      case SeriesEndType.onDate:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeriesEndTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

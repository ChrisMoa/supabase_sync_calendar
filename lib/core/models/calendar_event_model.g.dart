// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_event_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalendarEventModelAdapter extends TypeAdapter<CalendarEventModel> {
  @override
  final int typeId = 2;

  @override
  CalendarEventModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalendarEventModel(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      start: fields[3] as DateTime,
      end: fields[4] as DateTime,
      colorValue: fields[5] as int,
      userId: fields[6] as String,
      calendarId: fields[8] as String,
      wholeDay: fields[7] as bool,
      reminder: fields[9] as DateTime?,
      appendixes: (fields[10] as List).cast<String>(),
      isExternalReadOnly: fields[11] as bool,
      seriesId: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CalendarEventModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.start)
      ..writeByte(4)
      ..write(obj.end)
      ..writeByte(5)
      ..write(obj.colorValue)
      ..writeByte(6)
      ..write(obj.userId)
      ..writeByte(7)
      ..write(obj.wholeDay)
      ..writeByte(8)
      ..write(obj.calendarId)
      ..writeByte(9)
      ..write(obj.reminder)
      ..writeByte(10)
      ..write(obj.appendixes)
      ..writeByte(11)
      ..write(obj.isExternalReadOnly)
      ..writeByte(12)
      ..write(obj.seriesId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEventModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalendarModelAdapter extends TypeAdapter<CalendarModel> {
  @override
  final int typeId = 1;

  @override
  CalendarModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalendarModel(
      id: fields[0] as String,
      name: fields[1] as String,
      colorValue: fields[2] as int,
      userId: fields[3] as String,
      type: fields[4] as CalendarType,
      isDefault: fields[5] as bool,
      syncUrl: fields[6] as String?,
      deviceCalendarId: fields[7] as String?,
      lastSynced: fields[8] as DateTime?,
      isSynced: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CalendarModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorValue)
      ..writeByte(3)
      ..write(obj.userId)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.isDefault)
      ..writeByte(6)
      ..write(obj.syncUrl)
      ..writeByte(7)
      ..write(obj.deviceCalendarId)
      ..writeByte(8)
      ..write(obj.lastSynced)
      ..writeByte(9)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

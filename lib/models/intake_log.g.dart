// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'intake_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IntakeLogAdapter extends TypeAdapter<IntakeLog> {
  @override
  final int typeId = 1;

  @override
  IntakeLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IntakeLog(
      id: fields[0] as String,
      medicationName: fields[1] as String,
      timestamp: fields[2] as DateTime,
      status: fields[3] as String,
      scheduledTime: fields[4] as String?,
      notes: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, IntakeLog obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.medicationName)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.scheduledTime)
      ..writeByte(5)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntakeLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

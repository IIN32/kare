// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicationAdapter extends TypeAdapter<Medication> {
  @override
  final int typeId = 0;

  @override
  Medication read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Medication(
      name: fields[0] as String,
      dosage: fields[1] as String,
      times: (fields[2] as List).cast<String>(),
      frequency: fields[3] as int,
      startDate: fields[4] as DateTime,
      endDate: fields[5] as DateTime?,
      nagIntervals: (fields[6] as List?)?.cast<int>() ?? const [5, 10, 15],
      notes: fields[7] as String?,
      totalQuantity: fields[8] as int?,
      currentQuantity: fields[9] as int?,
      refillThreshold: fields[10] as int?,
      type: fields[11] as String?,
      profileId: fields[12] as String? ?? 'default',
      isArchived: fields[13] as bool? ?? false,
      urgency: fields[14] as String? ?? 'Normal',
    );
  }

  @override
  void write(BinaryWriter writer, Medication obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.dosage)
      ..writeByte(2)
      ..write(obj.times)
      ..writeByte(3)
      ..write(obj.frequency)
      ..writeByte(4)
      ..write(obj.startDate)
      ..writeByte(5)
      ..write(obj.endDate)
      ..writeByte(6)
      ..write(obj.nagIntervals)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.totalQuantity)
      ..writeByte(9)
      ..write(obj.currentQuantity)
      ..writeByte(10)
      ..write(obj.refillThreshold)
      ..writeByte(11)
      ..write(obj.type)
      ..writeByte(12)
      ..write(obj.profileId)
      ..writeByte(13)
      ..write(obj.isArchived)
      ..writeByte(14)
      ..write(obj.urgency);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

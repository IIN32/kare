import 'package:hive/hive.dart';

part 'profile.g.dart';

@HiveType(typeId: 2)
class Profile extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2) // New field
  final String? pin;
  
  @HiveField(3)
  int points;

  Profile({required this.id, required this.name, this.pin, this.points = 0});
}

import 'package:cloud_firestore/cloud_firestore.dart';

class DailyHallOfFameModel {
  final String id;
  final String categoryId;
  final String categoryName;
  final String categoryImage;
  final int votes;
  final DateTime date;
  final DateTime createdAt;

  DailyHallOfFameModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.categoryImage,
    required this.votes,
    required this.date,
    required this.createdAt,
  });

  factory DailyHallOfFameModel.fromMap(Map<String, dynamic> map, String id) {
    return DailyHallOfFameModel(
      id: id,
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      categoryImage: map['categoryImage'] ?? '',
      votes: map['votes'] ?? 0,
      date: (map['date'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class HallOfFameModel {
  final String id;
  final String categoryId;
  final String categoryName;
  final String categoryImage;
  final int votes;
  final DateTime month;  // 해당 월

  HallOfFameModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.categoryImage,
    required this.votes,
    required this.month,
  });

  factory HallOfFameModel.fromMap(Map<String, dynamic> map, String id) {
    return HallOfFameModel(
      id: id,
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      categoryImage: map['categoryImage'] ?? '',
      votes: map['votes'] ?? 0,
      month: (map['month'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categoryImage': categoryImage,
      'votes': votes,
      'month': Timestamp.fromDate(month),
    };
  }
}
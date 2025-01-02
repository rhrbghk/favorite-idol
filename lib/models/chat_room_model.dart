import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final String categoryId;  // 아이돌 카테고리 ID
  final String categoryName;  // 아이돌 이름
  final String categoryImage;  // 아이돌 이미지
  final int participantsCount;  // 참여자 수
  final DateTime createdAt;

  ChatRoomModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.categoryImage,
    this.participantsCount = 0,
    required this.createdAt,
  });

  factory ChatRoomModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatRoomModel(
      id: id,
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      categoryImage: map['categoryImage'] ?? '',
      participantsCount: map['participantsCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categoryImage': categoryImage,
      'participantsCount': participantsCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
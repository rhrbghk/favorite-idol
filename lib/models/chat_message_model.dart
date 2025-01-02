import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String userId;
  final String userName;
  final String message;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.message,
    required this.createdAt,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessageModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      message: map['message'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
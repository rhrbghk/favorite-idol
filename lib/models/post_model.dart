import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String? id;
  final List<String> imageUrls;  // 단일 imageUrl 대신 이미지 URL 리스트
  final String caption;
  final String categoryId;
  final String categoryName;
  final String userId;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final bool isLiked;

  PostModel({
    this.id,
    required this.imageUrls,  // 수정된 부분
    required this.caption,
    required this.categoryId,
    required this.categoryName,
    required this.userId,
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
    this.isLiked = false,
  });

  factory PostModel.fromMap(Map<String, dynamic> map, String id, {bool isLiked = false}) {
    return PostModel(
      id: id,
      imageUrls: List<String>.from(map['imageUrls'] ?? []),  // 수정된 부분
      caption: map['caption'] ?? '',
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      userId: map['userId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: map['likes'] ?? 0,
      comments: map['comments'] ?? 0,
      isLiked: isLiked,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrls': imageUrls,  // 수정된 부분
      'caption': caption,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'comments': comments,
    };
  }
}
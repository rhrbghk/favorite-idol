import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final String imageUrl;
  final DateTime createdAt;
  final int dailyVotes;
  final int weeklyVotes;
  final int monthlyVotes;
  final int totalVotes;

  CategoryModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.createdAt,
    this.dailyVotes = 0,
    this.weeklyVotes = 0,
    this.monthlyVotes = 0,
    this.totalVotes = 0,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dailyVotes: map['dailyVotes'] ?? 0,
      weeklyVotes: map['weeklyVotes'] ?? 0,
      monthlyVotes: map['monthlyVotes'] ?? 0,
      totalVotes: map['totalVotes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'dailyVotes': dailyVotes,
      'weeklyVotes': weeklyVotes,
      'monthlyVotes': monthlyVotes,
      'totalVotes': totalVotes,
    };
  }
}
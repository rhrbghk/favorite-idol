import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String nickname;
  final String? profileImage;
  final bool emailVerified;
  final DateTime createdAt;
  final int remainingVotes;
  final bool isKakaoUser;  // 추가

  UserModel({
    required this.uid,
    required this.email,
    required this.nickname,
    this.profileImage,
    required this.emailVerified,
    required this.createdAt,
    this.remainingVotes = 1,
    this.isKakaoUser = false,  // 기본값 false
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      email: map['email'] ?? '',
      nickname: map['nickname'] ?? '',  // 빈 문자열 유지
      profileImage: map['profileImage'],
      emailVerified: map['emailVerified'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      remainingVotes: map['remainingVotes'] ?? 1,
      isKakaoUser: map['isKakaoUser'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'nickname': nickname,
      'profileImage': profileImage,
      'emailVerified': emailVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'remainingVotes': remainingVotes,
      'isKakaoUser': isKakaoUser,
    };
  }
}
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:favorite_idol/screens/auth/login_screen.dart';
import 'package:favorite_idol/screens/profile/like_posts_screen.dart';
import 'package:favorite_idol/screens/profile/my_posts_screen.dart';
import 'package:favorite_idol/screens/profile/select_idols_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _updateProfileImage(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final user = context.read<AuthProvider>().user;

    if (user == null) return;

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 이미지 업로드
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profiles/${user.uid}.jpg');

      await storageRef.putFile(File(image.path));
      final imageUrl = await storageRef.getDownloadURL();

      // Firestore 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'profileImage': imageUrl});

      if (context.mounted) {
        Navigator.pop(context); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 이미지가 업데이트되었습니다')),
        );
      }
    } catch (e) {
      print('Error updating profile image: $e');
      if (context.mounted) {
        Navigator.pop(context); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 업데이트 중 오류가 발생했습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // 설정 화면으로 이동
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = UserModel.fromMap(
            snapshot.data!.data() as Map<String, dynamic>,
            snapshot.data!.id,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _updateProfileImage(context),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: userData.profileImage?.isNotEmpty == true
                            ? NetworkImage(userData.profileImage!)
                            : null,
                        child: userData.profileImage?.isNotEmpty != true
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  userData.nickname,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                _buildMenuItem(
                  icon: Icons.favorite,
                  title: '좋아요 목록',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LikedPostsScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuItem(
                  icon: Icons.history,
                  title: '활동 내역',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyPostsScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuItem(
                  icon: Icons.edit,
                  title: '프로필 수정',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuItem(
                  icon: Icons.star,
                  title: '내 아이돌 선택하기',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SelectIdolsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => _showLogoutDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('로그아웃'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        final error = await context.read<AuthProvider>().signOut();

        if (context.mounted) {
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          } else {
            // 로그아웃 성공시 LoginScreen으로 이동
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,  // 스택의 모든 화면 제거
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그아웃 중 오류가 발생했습니다')),
          );
        }
      }
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:favorite_idol/screens/posts/post_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';

class LikedPostsScreen extends StatelessWidget {
  const LikedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('좋아요 목록'),
        ),
        body: const Center(
          child: Text('로그인이 필요합니다'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('좋아요 목록'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('에러가 발생했습니다: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return FutureBuilder<List<DocumentSnapshot?>>(
            future: Future.wait(
              snapshot.data!.docs.map((doc) async {
                try {
                  final likeDoc = await doc.reference
                      .collection('likes')
                      .doc(user.uid)
                      .get();

                  return likeDoc.exists ? doc : null;
                } catch (e) {
                  print('Error checking likes: $e');
                  return null;
                }
              }),
            ),
            builder: (context, asyncSnapshot) {
              if (asyncSnapshot.hasError) {
                return Center(child: Text('에러가 발생했습니다: ${asyncSnapshot.error}'));
              }

              if (!asyncSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final likedPosts = asyncSnapshot.data!
                  .where((doc) => doc != null)
                  .cast<DocumentSnapshot>()
                  .toList();

              if (likedPosts.isEmpty) {
                return const Center(child: Text('좋아요한 게시물이 없습니다'));
              }

              return ListView.builder(
                itemCount: likedPosts.length,
                itemBuilder: (context, index) {
                  final doc = likedPosts[index];  // DocumentSnapshot 가져오기
                  final post = PostModel.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: post.imageUrls.isNotEmpty
                          ? Image.network(
                        post.imageUrls[0],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                          : const Icon(Icons.image_not_supported),
                      title: Text(post.caption),
                      subtitle: Text('좋아요 ${post.likes}개'),
                      onTap: () async {
                        final postDoc = await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(doc.id)
                            .get();

                        if (postDoc.exists && context.mounted) {
                          final postData = postDoc.data();
                          // null 체크 추가
                          if (postData != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailScreen(
                                  post: postDoc,
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
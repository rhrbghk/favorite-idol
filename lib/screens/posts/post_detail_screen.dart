import 'package:favorite_idol/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostDetailScreen extends StatelessWidget {
  final DocumentSnapshot post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final postData = post.data() as Map<String, dynamic>?;
    if (postData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('게시글'),
        ),
        body: const Center(
          child: Text('게시글을 불러올 수 없습니다'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(postData['categoryName'] ?? '게시글'),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'bookmark',
                child: Text('북마크'),
              ),
              // user?.uid 대신 안전한 비교
              if (postData['userId'] == context.read<AuthProvider>().user?.uid)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('삭제'),
                ),
            ],
            onSelected: (value) async {
              if (value == 'delete') {
                // 삭제 확인 다이얼로그
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('게시글 삭제'),
                    content: const Text('이 게시글을 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('삭제', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (result == true) {
                  await post.reference.delete();
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              } else if (value == 'bookmark') {
                // 북마크 기능 구현
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작성자 정보
            ListTile(
              leading: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(postData['userId'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircleAvatar();
                  }
                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  return CircleAvatar(
                    backgroundImage: NetworkImage(userData['profileImage'] ?? ''),
                  );
                },
              ),
              title: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(postData['userId'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text('사용자');
                  }
                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  return Text(userData['nickname'] ?? '사용자');
                },
              ),
              subtitle: Text(
                postData['createdAt'] != null
                    ? timeago.format(
                  (postData['createdAt'] as Timestamp).toDate(),
                  locale: 'ko',
                )
                    : '',
              ),
            ),

            // 이미지
            AspectRatio(
              aspectRatio: 1,
              child: PageView.builder(
                itemCount: (postData['imageUrls'] as List?)?.length ?? 0,
                itemBuilder: (context, index) {
                  final imageUrls = postData['imageUrls'] as List?;
                  if (imageUrls == null || imageUrls.isEmpty) {
                    return const Center(
                      child: Icon(Icons.image_not_supported),
                    );
                  }

                  return Image.network(
                    imageUrls[index],
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),

            // 좋아요, 댓글, 북마크 버튼
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    postData['isLiked'] ?? false
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: postData['isLiked'] ?? false ? Colors.red : null,
                  ),
                  onPressed: () {
                    // 좋아요 기능 구현
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () {
                    // 댓글 입력으로 포커스
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: () {
                    // 북마크 기능 구현
                  },
                ),
              ],
            ),

            // 좋아요 수
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '좋아요 ${postData['likes'] ?? 0}개',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            // 캡션
            if (postData['caption'] != null && postData['caption'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(postData['caption']),
              ),

            // 댓글 목록
            StreamBuilder<QuerySnapshot>(
              stream: post.reference
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: snapshot.data!.docs.map((comment) {
                    final commentData = comment.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(commentData['userId'])
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircleAvatar();
                          }
                          final userData =
                          snapshot.data!.data() as Map<String, dynamic>;
                          return CircleAvatar(
                            backgroundImage:
                            NetworkImage(userData['profileImage'] ?? ''),
                          );
                        },
                      ),
                      title: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(commentData['userId'])
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Text('사용자');
                          }
                          final userData =
                          snapshot.data!.data() as Map<String, dynamic>;
                          return Text(userData['nickname'] ?? '사용자');
                        },
                      ),
                      subtitle: Text(commentData['text']),
                      trailing: Text(
                        timeago.format(
                          (commentData['createdAt'] as Timestamp).toDate(),
                          locale: 'ko',
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
      // 댓글 입력
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircleAvatar(),
            ),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '댓글 달기...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: (text) async {
                  if (text.isNotEmpty) {
                    await post.reference.collection('comments').add({
                      'userId': '현재 로그인한 유저 ID',
                      'text': text,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
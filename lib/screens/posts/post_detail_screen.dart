import 'package:favorite_idol/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostDetailScreen extends StatelessWidget {
  final DocumentSnapshot post;

  const PostDetailScreen({super.key, required this.post});

  Future<void> _deletePost(BuildContext context, Map<String, dynamic> postData) async {
    try {
      // 이미지 삭제
      for (String imageUrl in postData['imageUrls']) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          print('Error deleting image: $e');
        }
      }

      // Firestore 문서 삭제
      await post.reference.delete();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시글이 삭제되었습니다')),
        );
      }
    } catch (e) {
      print('Error deleting post: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시글 삭제 중 오류가 발생했습니다')),
        );
      }
    }
  }

  Future<void> _reportPost(BuildContext context) async {
    final currentUser = context.read<AuthProvider>().user;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시글 신고'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('스팸'),
              onTap: () => Navigator.pop(context, 'spam'),
            ),
            ListTile(
              title: const Text('불건전한 내용'),
              onTap: () => Navigator.pop(context, 'inappropriate'),
            ),
            ListTile(
              title: const Text('혐오 발언'),
              onTap: () => Navigator.pop(context, 'hate'),
            ),
            ListTile(
              title: const Text('기타'),
              onTap: () => Navigator.pop(context, 'other'),
            ),
          ],
        ),
      ),
    );

    if (reason != null && context.mounted) {
      try {
        await FirebaseFirestore.instance.collection('reports').add({
          'postId': post.id,
          'reporterId': currentUser?.uid,
          'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('신고가 접수되었습니다')),
          );
        }
      } catch (e) {
        print('Error reporting post: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('신고 중 오류가 발생했습니다')),
          );
        }
      }
    }
  }

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

    final currentUser = context.read<AuthProvider>().user;
    final isMyPost = postData['userId'] == currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(postData['categoryName'] ?? '게시글'),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) {
              if (isMyPost) {
                return [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20),
                        SizedBox(width: 8),
                        Text('삭제하기'),
                      ],
                    ),
                  ),
                ];
              } else {
                return [
                  const PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.report, size: 20),
                        SizedBox(width: 8),
                        Text('신고하기'),
                      ],
                    ),
                  ),
                ];
              }
            },
            onSelected: (value) async {
              if (value == 'delete') {
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
                        child: const Text(
                          '삭제',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (result == true) {
                  await _deletePost(context, postData);
                }
              } else if (value == 'report') {
                await _reportPost(context);
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
                  if (text.isNotEmpty && currentUser != null) {
                    await post.reference.collection('comments').add({
                      'userId': currentUser.uid,
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
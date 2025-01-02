import 'dart:io';
import 'package:favorite_idol/models/category_model.dart';
import 'package:favorite_idol/models/post_model.dart';
import 'package:favorite_idol/models/user_model.dart';
import 'package:favorite_idol/models/widget/comments/comment_bottom_sheet.dart';
import 'package:favorite_idol/providers/auth_provider.dart';
import 'package:favorite_idol/screens/posts/create_post_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedCategories = <String>{};
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCreateCategoryDialog() async {
    final TextEditingController nameController = TextEditingController();
    File? imageFile;

    try {
      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('나만의 아이돌 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '아이돌 이름',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder: (context, setState) => Column(
                    children: [
                      if (imageFile != null)
                        Container(
                          width: 100,
                          height: 100,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: FileImage(imageFile!),
                              fit: BoxFit.cover,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ElevatedButton(
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            maxHeight: 800,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            setState(() {
                              imageFile = File(image.path);
                            });
                          }
                        },
                        child: Text(imageFile == null ? '프로필 이미지 선택' : '이미지 변경'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || imageFile == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이름과 이미지를 모두 입력해주세요')),
                  );
                  return;
                }

                try {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  // 이미지 업로드
                  final storageRef = FirebaseStorage.instance
                      .ref()
                      .child('categories/${DateTime.now().millisecondsSinceEpoch}.jpg');

                  await storageRef.putFile(
                    imageFile!,
                    SettableMetadata(contentType: 'image/jpeg'),
                  );

                  final imageUrl = await storageRef.getDownloadURL();

                  // 트랜잭션으로 카테고리와 채팅방 동시에 생성
                  await FirebaseFirestore.instance.runTransaction((transaction) async {
                    // 1. 카테고리 추가
                    final categoryRef = FirebaseFirestore.instance.collection('categories').doc();

                    final categoryData = CategoryModel(
                      id: categoryRef.id,
                      name: nameController.text,
                      imageUrl: imageUrl,
                      createdAt: DateTime.now(),
                      dailyVotes: 0,
                      weeklyVotes: 0,
                      monthlyVotes: 0,
                      totalVotes: 0,
                    ).toMap();

                    transaction.set(categoryRef, categoryData);

                    // 2. 채팅방 생성
                    final chatRoomRef = FirebaseFirestore.instance
                        .collection('chatRooms')
                        .doc(categoryRef.id);

                    transaction.set(chatRoomRef, {
                      'categoryId': categoryRef.id,
                      'categoryName': nameController.text,
                      'categoryImage': imageUrl,
                      'participantsCount': 0,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  });

                  if (context.mounted) {
                    Navigator.pop(context); // 로딩 닫기
                    Navigator.pop(dialogContext); // 다이얼로그 닫기
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('아이돌이 추가되었습니다')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // 로딩 닫기
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('아이돌 추가 실패: $e')),
                    );
                  }
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('아이돌 추가 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  Widget _buildPostList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _selectedCategories.isEmpty
          ? FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots()
          : FirebaseFirestore.instance
          .collection('posts')
          .where('categoryId', whereIn: _selectedCategories.toList())
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('에러가 발생했습니다: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('게시물이 없습니다.'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];

            // 현재 사용자의 좋아요 상태를 확인
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(doc.id)
                  .collection('likes')
                  .doc(context.read<AuthProvider>().user?.uid)
                  .snapshots(),
              builder: (context, likeSnapshot) {
                final isLiked = likeSnapshot.hasData && likeSnapshot.data!.exists;
                final post = PostModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                  isLiked: isLiked,
                );
                return _buildPostCard(post);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPostCard(PostModel post) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostHeader(post),
          _buildPostImage(post),
          _buildPostActions(post),
          _buildPostDetails(post),
        ],
      ),
    );
  }

  Widget _buildPostHeader(PostModel post) {
    print('Building header for post with userId: ${post.userId}'); // 디버그 로그 추가

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(post.userId)
          .snapshots(),
      builder: (context, snapshot) {
        print('Stream builder state: hasData=${snapshot.hasData}, hasError=${snapshot.hasError}'); // 디버그 로그 추가

        if (!snapshot.hasData) {
          return const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text('로딩 중...'),
          );
        }

        if (!snapshot.data!.exists) {
          print('User document does not exist for ID: ${post.userId}'); // 디버그 로그 추가
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text('사용자를 찾을 수 없습니다'),
            subtitle: Text('User ID: ${post.userId}'), // 디버깅용 ID 표시
          );
        }

        try {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final userData = UserModel.fromMap(data, snapshot.data!.id);

          print('Successfully loaded user data: ${userData.nickname}'); // 디버그 로그 추가

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: userData.profileImage?.isNotEmpty == true
                  ? NetworkImage(userData.profileImage!)
                  : null,
              child: userData.profileImage?.isNotEmpty != true
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(userData.nickname),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                // 게시물 메뉴 구현
              },
            ),
          );
        } catch (e) {
          print('Error parsing user data: $e'); // 디버그 로그 추가
          return const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text('데이터 로드 오류'),
          );
        }
      },
    );
  }

  Widget _buildPostImage(PostModel post) {
    if (post.imageUrls.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Icon(Icons.error)),
      );
    }

    return SizedBox(
      height: 400, // 이미지 컨테이너의 높이 지정
      child: PageView.builder(
        itemCount: post.imageUrls.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Image.network(
                post.imageUrls[index],
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: Icon(Icons.error)),
                  );
                },
              ),
              // 이미지가 여러장일 경우 페이지 인디케이터 표시
              if (post.imageUrls.length > 1)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${index + 1}/${post.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPostActions(PostModel post) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            post.isLiked ? Icons.favorite : Icons.favorite_border,
            color: post.isLiked ? Colors.red : null,
          ),
          onPressed: () async {
            try {
              final currentUser = context.read<AuthProvider>().user;
              if (currentUser == null) return;

              final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
              final likeRef = postRef.collection('likes').doc(currentUser.uid);

              if (post.isLiked) {
                // 좋아요 취소
                await likeRef.delete();
                await postRef.update({
                  'likes': FieldValue.increment(-1),
                });
              } else {
                // 좋아요 추가
                await likeRef.set({
                  'userId': currentUser.uid,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                await postRef.update({
                  'likes': FieldValue.increment(1),
                });
              }
            } catch (e) {
              print('Error toggling like: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('좋아요 처리 중 오류가 발생했습니다')),
              );
            }
          },
        ),

        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => CommentBottomSheet(post: post),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPostDetails(PostModel post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 좋아요 수 표시
          Text(
            '좋아요 ${post.likes}개',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (post.caption.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(post.caption),
          ],
          const SizedBox(height: 8),
          // 댓글 수 표시
          Text(
            '댓글 ${post.comments}개',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('아이돌 갤러리'),
        leadingWidth: 50,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreatePostScreen()),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildPostList(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          const UserAccountsDrawerHeader(
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person),
            ),
            accountName: Text('카테고리 필터'),
            accountEmail: null,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '아이돌 검색...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle, color: Colors.blue),
            title: const Text('나만의 아이돌 추가'),
            onTap: () {
              Navigator.pop(context); // 드로어 닫기
              _showCreateCategoryDialog();
            },
          ),
          const Divider(),
          Expanded(
            child: _buildCategoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data!.docs
            .where((doc) =>
            (doc['name'] as String).toLowerCase().contains(_searchQuery))
            .toList();

        return ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = _selectedCategories.contains(category.id);

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(category['imageUrl']),
              ),
              title: Text(category['name']),
              trailing: Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedCategories.add(category.id);
                    } else {
                      _selectedCategories.remove(category.id);
                    }
                  });
                },
              ),
            );
          },
        );
      },
    );
  }
}
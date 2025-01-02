import 'package:favorite_idol/models/post_model.dart';
import 'package:favorite_idol/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  List<XFile> _imageFiles = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _captionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (images.isNotEmpty) {
      setState(() {
        if (_imageFiles.length + images.length > 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('최대 10장까지만 선택할 수 있습니다')),
          );
          _imageFiles = _imageFiles + images.take(10 - _imageFiles.length).toList();
        } else {
          _imageFiles = _imageFiles + images;
        }
      });
    }
  }

  Future<void> _uploadPost() async {
    if (_imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 선택해주세요')),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 선택해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = context.read<AuthProvider>().user;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      List<String> imageUrls = [];

      for (var imageFile in _imageFiles) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('posts/${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.jpg');

        await storageRef.putFile(File(imageFile.path));
        final imageUrl = await storageRef.getDownloadURL();
        imageUrls.add(imageUrl);
      }

      final post = PostModel(
        imageUrls: imageUrls,
        caption: _captionController.text,
        categoryId: _selectedCategoryId!,
        categoryName: _selectedCategoryName!,
        userId: currentUser.uid,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('posts')
          .add(post.toMap());

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error uploading post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  Widget _buildImagePreview() {
    return Container(
      height: 200,
      child: _imageFiles.isEmpty
          ? GestureDetector(
        onTap: _selectImages,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate, size: 50),
              Text('사진 추가 (최대 10장)'),
            ],
          ),
        ),
      )
          : ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _imageFiles.length + 1,
        itemBuilder: (context, index) {
          if (index == _imageFiles.length && index < 10) {
            return GestureDetector(
              onTap: _selectImages,
              child: Container(
                width: 150,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_photo_alternate),
              ),
            );
          }
          return Stack(
            children: [
              Container(
                width: 150,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(File(_imageFiles[index].path)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 16,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
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

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '카테고리 선택',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '카테고리 검색...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('categories')
              .orderBy('name') // 이름순 정렬 추가
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final categories = snapshot.data!.docs
                .where((doc) =>
                (doc['name'] as String)
                    .toLowerCase()
                    .contains(_searchQuery))
                .toList();

            return SizedBox(
              height: 200,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = category.id == _selectedCategoryId;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = category.id;
                        _selectedCategoryName = category['name'];
                      });
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: NetworkImage(category['imageUrl']),
                          backgroundColor: isSelected
                              ? Colors.blue
                              : Colors.grey[200],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category['name'],
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 게시글'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _uploadPost,
            child: const Text('공유'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePreview(),
            const SizedBox(height: 16),
            _buildCategorySelector(),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                hintText: '문구 입력...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}
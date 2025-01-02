import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:favorite_idol/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SelectIdolsScreen extends StatefulWidget {
  const SelectIdolsScreen({super.key});

  @override
  State<SelectIdolsScreen> createState() => _SelectIdolsScreenState();
}

class _SelectIdolsScreenState extends State<SelectIdolsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedIdols = {};

  @override
  void initState() {
    super.initState();
    _loadSelectedIdols();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 저장된 선택 아이돌 불러오기
  Future<void> _loadSelectedIdols() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data()?['favoriteIdols'] != null) {
        setState(() {
          _selectedIdols.addAll(
            List<String>.from(doc.data()!['favoriteIdols']),
          );
        });
      }
    } catch (e) {
      print('Error loading favorite idols: $e');
    }
  }

  Future<void> _saveSelectedIdols() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'favoriteIdols': _selectedIdols.toList()});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택한 아이돌이 저장되었습니다')),
        );
      }
    } catch (e) {
      print('Error saving favorite idols: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 아이돌 선택'),
        actions: [
          TextButton(
            onPressed: _saveSelectedIdols,
            child: const Text('저장'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('categories')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final categories = snapshot.data!.docs
                    .where((doc) =>
                    (doc['name'] as String)
                        .toLowerCase()
                        .contains(_searchQuery))
                    .toList();

                return ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedIdols.contains(category.id);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(category['imageUrl']),
                      ),
                      title: Text(category['name']),
                      trailing: IconButton(
                        icon: Icon(
                          isSelected ? Icons.star : Icons.star_border,
                          color: isSelected ? Colors.amber : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isSelected) {
                              _selectedIdols.remove(category.id);
                            } else {
                              _selectedIdols.add(category.id);
                            }
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
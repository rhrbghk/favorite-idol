import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

class OtherScreen extends StatelessWidget {
  const OtherScreen({super.key});

  Future<void> _vote(BuildContext context, CategoryModel category) async {
    try {
      final user = context.read<AuthProvider>().user;
      if (user == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다')),
          );
        }
        return;
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 트랜잭션 내에서 문서 읽기
        final userDoc = await transaction.get(
            FirebaseFirestore.instance.collection('users').doc(user.uid)
        );

        final categoryDoc = await transaction.get(
            FirebaseFirestore.instance.collection('categories').doc(category.id)
        );

        if (!userDoc.exists || !categoryDoc.exists) {
          throw Exception('필요한 문서가 존재하지 않습니다');
        }

        final userData = UserModel.fromMap(userDoc.data()!, userDoc.id);
        if (userData.remainingVotes <= 0) {
          throw Exception('남은 투표권이 없습니다');
        }

        // 카테고리 문서 업데이트
        transaction.update(categoryDoc.reference, {
          'dailyVotes': FieldValue.increment(1),
          'weeklyVotes': FieldValue.increment(1),
          'monthlyVotes': FieldValue.increment(1),
          'totalVotes': FieldValue.increment(1),
        });

        // 사용자 문서 업데이트
        transaction.update(userDoc.reference, {
          'remainingVotes': FieldValue.increment(-1),
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${category.name}에게 투표했습니다!')),
        );
      }
    } catch (e) {
      print('Vote error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              e.toString().contains('남은 투표권이 없습니다')
                  ? '남은 투표권이 없습니다'
                  : '투표 중 오류가 발생했습니다'
          )),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('투표하기'),
      ),
      body: user == null
          ? const Center(child: Text('로그인이 필요합니다'))
          : StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = UserModel.fromMap(
            userSnapshot.data!.data() as Map<String, dynamic>,
            userSnapshot.data!.id,
          );

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('categories')
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final categories = snapshot.data!.docs
                  .map((doc) => CategoryModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
                  .toList();

              return Column(
                children: [
                  // 남은 투표권 표시
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Color(0XFFefb8da),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite, color: Colors.pink),
                        const SizedBox(width: 8),
                        Text(
                          '남은 투표권: ${userData.remainingVotes}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 아이돌 목록
                  Expanded(
                    child: ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(category.imageUrl),
                          ),
                          title: Text(
                            category.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.favorite,
                              color: Colors.pink,
                            ),
                            onPressed: userData.remainingVotes > 0
                                ? () => _vote(context, category)
                                : null,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('오늘 ${category.dailyVotes}표'),
                              Text('전체 ${category.totalVotes}표'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
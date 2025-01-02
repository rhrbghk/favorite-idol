import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/category_model.dart';

class MonthlyRankingScreen extends StatelessWidget {
  const MonthlyRankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('월간 랭킹'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .orderBy('monthlyVotes', descending: true)
            .limit(100)
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

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final rank = index + 1;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: rank <= 3 ? Colors.amber : Colors.grey[300],
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: rank <= 3 ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    category.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('이번 달 ${category.monthlyVotes}표'),
                  trailing: CircleAvatar(
                    backgroundImage: NetworkImage(category.imageUrl),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
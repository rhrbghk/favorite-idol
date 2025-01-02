import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:favorite_idol/models/hallof_fame_model.dart';
import 'package:flutter/material.dart';

class HallOfFameScreen extends StatelessWidget {
  const HallOfFameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('명예의 전당'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('hallOfFame')
            .orderBy('month', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!.docs
              .map((doc) => HallOfFameModel.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ))
              .toList();

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(item.categoryImage),
                  ),
                  title: Text(
                    item.categoryName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${item.month.year}년 ${item.month.month}월\n'
                        '${item.votes}표',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.emoji_events, color: Colors.amber),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
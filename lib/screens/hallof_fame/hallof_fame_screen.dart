import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:favorite_idol/models/hallof_fame_model.dart';
import 'package:flutter/material.dart';

class HallOfFameScreen extends StatefulWidget {
  const HallOfFameScreen({super.key});

  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('명예의 전당'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '월간 순위'),
            Tab(text: '일간 순위'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MonthlyHallOfFameTab(),
          DailyHallOfFameTab(),
        ],
      ),
    );
  }
}

class MonthlyHallOfFameTab extends StatelessWidget {
  const MonthlyHallOfFameTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('hallOfFame')
          .orderBy('month', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!.docs;

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index].data() as Map<String, dynamic>;
            final date = (item['month'] as Timestamp).toDate();

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(item['categoryImage']),
              ),
              title: Text(item['categoryName']),
              subtitle: Text(
                '${date.year}년 ${date.month}월\n'
                    '${item['votes']}표',
              ),
              trailing: const Icon(Icons.emoji_events, color: Colors.amber),
            );
          },
        );
      },
    );
  }
}

class DailyHallOfFameTab extends StatelessWidget {
  const DailyHallOfFameTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dailyHallOfFame')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!.docs;

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index].data() as Map<String, dynamic>;
            final date = (item['date'] as Timestamp).toDate();

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(item['categoryImage']),
              ),
              title: Text(item['categoryName']),
              subtitle: Text(
                '${date.year}년 ${date.month}월 ${date.day}일\n'
                    '${item['votes']}표',
              ),
              trailing: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star, color: Colors.amber),
              ),
            );
          },
        );
      },
    );
  }
}
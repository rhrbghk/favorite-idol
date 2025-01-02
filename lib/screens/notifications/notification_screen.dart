import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // 알림 설정 화면으로 이동
            },
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: 10, // 임시 데이터 개수
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.notifications),
            ),
            title: Text('알림 제목 ${index + 1}'),
            subtitle: Text('알림 내용 ${index + 1}'),
            trailing: Text('${index + 1}시간 전'),
            onTap: () {
              // 알림 클릭 시 처리
            },
          );
        },
      ),
    );
  }
}
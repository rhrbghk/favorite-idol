import 'package:favorite_idol/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/chat_room_model.dart';
import '../../models/chat_message_model.dart';
import '../../providers/auth_provider.dart';

class ChatRoomScreen extends StatefulWidget {
  final ChatRoomModel chatRoom;

  const ChatRoomScreen({super.key, required this.chatRoom});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _userId; // 사용자 ID를 저장할 변수 추가


  @override
  void initState() {
    super.initState();
    // initState에서 사용자 ID를 저장
    _userId = context.read<AuthProvider>().user?.uid;
    _addParticipant();
  }

  @override
  void dispose() {
    // 저장된 userId 사용
    _removeParticipant(_userId);
    super.dispose();
  }

  Future<void> _addParticipant() async {
    if (_userId == null) return;

    try {
      final participantRef = FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.chatRoom.id)
          .collection('participants')
          .doc(_userId);

      await participantRef.set({
        'userId': _userId,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });

      final participantsCount = (await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.chatRoom.id)
          .collection('participants')
          .count()
          .get()).count;

      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.chatRoom.id)
          .update({
        'participantsCount': participantsCount,
      });
    } catch (e) {
      print('Error adding participant: $e');
    }
  }

  Future<void> _removeParticipant(String? userId) async {
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.chatRoom.id)
          .collection('participants')
          .doc(userId)
          .delete();

      final participantsCount = (await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.chatRoom.id)
          .collection('participants')
          .count()
          .get()).count;

      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.chatRoom.id)
          .update({
        'participantsCount': participantsCount,
      });
    } catch (e) {
      print('Error removing participant: $e');
    }
  }


  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      // 사용자 정보를 가져옴
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = UserModel.fromMap(userDoc.data()!, userDoc.id);

      // 메시지 저장 시 실제 닉네임을 저장
      final messageRef = await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.chatRoom.id)
          .collection('messages')
          .add({
        'userId': user.uid,
        'userName': userData.nickname, // Anonymous 대신 실제 닉네임 사용
        'message': _messageController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _messageController.clear();

      // 스크롤 컨트롤러가 attached 상태일 때만 스크롤
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메시지 전송 중 오류가 발생했습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.chatRoom.categoryImage),
            ),
            const SizedBox(width: 8),
            Text(widget.chatRoom.categoryName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chatRooms')
                  .doc(widget.chatRoom.id)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // createdAt이 null인 경우 현재 시간으로 대체
                  if (data['createdAt'] == null) {
                    data['createdAt'] = Timestamp.now();
                  }
                  return ChatMessageModel.fromMap(data, doc.id);
                }).toList();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.userId ==
                        context.read<AuthProvider>().user?.uid;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue[100] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Text(
                                    message.userName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                Text(message.message),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '메시지 입력...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
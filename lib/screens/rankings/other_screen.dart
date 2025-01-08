import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

class OtherScreen extends StatefulWidget {
  const OtherScreen({super.key});

  @override
  State<OtherScreen> createState() => _OtherScreenState();
}

class _OtherScreenState extends State<OtherScreen> {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  final String _rewardedAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917'  // Android 테스트 ID
      : 'ca-app-pub-3940256099942544/1712485313'; // iOS 테스트 ID

  void _loadRewardedAd() {
    setState(() => _isLoading = true);

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          setState(() => _isLoading = false);
          _showRewardedAd();
        },
        onAdFailedToLoad: (error) {
          print('Failed to load rewarded ad: ${error.message}');
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('광고 로드 중 오류가 발생했습니다')),
            );
          }
        },
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd == null) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('Failed to show rewarded ad: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('광고 표시 중 오류가 발생했습니다')),
          );
        }
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (_, reward) async {
      final user = context.read<AuthProvider>().user;
      if (user == null) return;

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'remainingVotes': FieldValue.increment(1),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('추가 투표 기회를 획득했습니다!')),
          );
        }
      } catch (e) {
        print('Error updating votes: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('투표권 추가 중 오류가 발생했습니다')),
          );
        }
      }
    });
  }

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

        transaction.update(categoryDoc.reference, {
          'dailyVotes': FieldValue.increment(1),
          'weeklyVotes': FieldValue.increment(1),
          'monthlyVotes': FieldValue.increment(1),
        });

        transaction.update(userDoc.reference, {
          'remainingVotes': FieldValue.increment(-1),
        });
      });

      if (!context.mounted) return;

      // 현재 사용자 데이터 가져오기
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final currentUserData = UserModel.fromMap(
        currentUserDoc.data()!,
        currentUserDoc.id,
      );

      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text('${category.name}에게 투표했습니다!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 50,
              ),
              const SizedBox(height: 16),
              const Text('광고를 시청하고 추가 투표권을 받으시겠습니까?'),
              const SizedBox(height: 8),
              Text(
                '현재 남은 투표 수: ${currentUserData.remainingVotes}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('다음에 하기'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : () {
                Navigator.pop(dialogContext);
                _loadRewardedAd();
              },
              child: const Text('광고 보기'),
            ),
          ],
        ),
      );
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0XFFefb8da),
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
                              Text('이번달 ${category.monthlyVotes}표'),
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
import 'dart:async';
import 'dart:io';
import 'package:favorite_idol/models/category_model.dart';
import 'package:favorite_idol/models/post_model.dart';
import 'package:favorite_idol/models/user_model.dart';
import 'package:favorite_idol/models/widget/remaining_time_widget.dart';
import 'package:favorite_idol/providers/auth_provider.dart';
import 'package:favorite_idol/screens/chat/chat_list_screen.dart';
import 'package:favorite_idol/screens/hallof_fame/hallof_fame_screen.dart';
import 'package:favorite_idol/screens/posts/post_detail_screen.dart';
import 'package:favorite_idol/screens/rankings/daily_ranking_screen.dart';
import 'package:favorite_idol/screens/rankings/monthly_ranking_screen.dart';
import 'package:favorite_idol/screens/rankings/other_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _showAdDialog() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists || !mounted) return;

      final userData = UserModel.fromMap(userDoc.data()!, userDoc.id);
      if (userData.remainingVotes > 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미 추가 투표권이 있습니다')),
          );
        }
        return;
      }

      RewardedAd? rewardedAd;
      final adUnitId = Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917' // Android 테스트 ID
          : 'ca-app-pub-3940256099942544/1712485313'; // iOS 테스트 ID

      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('광고 시청'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_circle_outline,
                size: 50,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text('광고를 시청하고 추가 투표 기회를 받으시겠습니까?'),
              const SizedBox(height: 16),
              Text(
                '현재 남은 투표 수: ${userData.remainingVotes}',
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
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // 광고 로드
                await RewardedAd.load(
                  adUnitId: adUnitId,
                  request: const AdRequest(),
                  rewardedAdLoadCallback: RewardedAdLoadCallback(
                    onAdLoaded: (ad) {
                      rewardedAd = ad;
                      rewardedAd!.show(
                        onUserEarnedReward: (_, reward) async {
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .update({
                              'remainingVotes': FieldValue.increment(1),
                            });

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('추가 투표 기회를 획득했습니다!')),
                              );
                            }
                          } catch (e) {
                            print('Error updating votes: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('오류가 발생했습니다')),
                              );
                            }
                          }
                        },
                      );
                    },
                    onAdFailedToLoad: (error) {
                      print('Failed to load rewarded ad: ${error.message}');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('광고 로드 중 오류가 발생했습니다')),
                        );
                      }
                    },
                  ),
                );
              },
              child: const Text('광고 보기'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error showing ad dialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Image.asset(
          'assets/images/fa_icon_land_text_ver2.png',
          height: 28, // AppBar 높이에 맞게 적절한 크기 설정
          fit: BoxFit.contain, // 이미지 비율 유지하면서 맞춤
        ),
        actions: [
          if (user != null)
            Flexible(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const SizedBox();
                  }

                  try {
                    final userData = UserModel.fromMap(
                      snapshot.data!.data() as Map<String, dynamic>,
                      snapshot.data!.id,
                    );

                    return TextButton.icon(
                      onPressed: _showAdDialog,
                      icon: const Icon(Icons.favorite, color: Colors.pink),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${userData.remainingVotes}표 ',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const RemainingTimeWidget(),
                        ],
                      ),
                    );
                  } catch (e) {
                    print('Error building user data: $e');
                    return const SizedBox();
                  }
                },
              ),
            ),
          IconButton(
            icon: Icon(
              Icons.notifications,
              color: Colors.yellow[700],
            ),
            onPressed: () {
              // 알림 기능 구현
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTopBanner(),
              _buildMenuButtons(),
              if (user != null) ...[
                _buildFavoriteIdolFeed(user),
                const SizedBox(height: 24),
                _buildPopularFeed(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0XFFefb8da),
        ),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '오늘의 1등 아이돌',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTopIdol(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopIdol() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .orderBy('dailyVotes', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('오류가 발생했습니다');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Text('데이터가 없습니다');
        }

        try {
          final topIdol = CategoryModel.fromMap(
            snapshot.data!.docs.first.data() as Map<String, dynamic>,
            snapshot.data!.docs.first.id,
          );

          return Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: topIdol.imageUrl.isNotEmpty
                    ? NetworkImage(topIdol.imageUrl) as ImageProvider
                    : const AssetImage('assets/images/placeholder.png'),
                onBackgroundImageError: (_, __) {},
                child:
                    topIdol.imageUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topIdol.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '오늘 ${topIdol.dailyVotes}표',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        } catch (e) {
          print('Error building top idol: $e');
          return const Text('데이터를 불러올 수 없습니다');
        }
      },
    );
  }

  Widget _buildMenuButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMenuButton(
            context,
            '일간 랭킹',
            CupertinoIcons.star,
            const DailyRankingScreen(),
          ),
          _buildMenuButton(
            context,
            '월간 랭킹',
            CupertinoIcons.star_fill,
            const MonthlyRankingScreen(),
          ),
          _buildMenuButton(
            context,
            '명예의 전당',
            CupertinoIcons.sparkles,
            const HallOfFameScreen(),
          ),
          _buildMenuButton(
            context,
            '투표',
            CupertinoIcons.ticket_fill,
            const OtherScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    IconData icon,
    Widget screen,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1), // 그림자 색상
                  blurRadius: 8, // 흐림 정도
                  spreadRadius: 2, // 확산 정도
                  offset: const Offset(4, 4), // X: 4, Y: 4 방향으로 그림자 이동
                ),
              ],
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0XFFefb8da), size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteIdolFeed(user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 최애 아이돌 피드',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const Center(child: CircularProgressIndicator());
                }

                try {
                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  final favoriteIdols =
                      List<String>.from(userData['favoriteIdols'] ?? []);

                  if (favoriteIdols.isEmpty) {
                    return const Center(child: Text('아이돌을 선택해주세요'));
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .where('categoryId', whereIn: favoriteIdols)
                        .orderBy('createdAt', descending: true)
                        .limit(5)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('게시물이 없습니다'));
                      }

                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final doc = snapshot.data!.docs[index];
                          try {
                            final post = PostModel.fromMap(
                              doc.data() as Map<String, dynamic>,
                              doc.id,
                            );
                            return _buildPostCard(post, doc);
                          } catch (e) {
                            print('Error building post card: $e');
                            return const SizedBox();
                          }
                        },
                      );
                    },
                  );
                } catch (e) {
                  print('Error building favorite idol feed: $e');
                  return const Center(child: Text('데이터를 불러올 수 없습니다'));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularFeed() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘의 인기 피드',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .orderBy('likes', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('게시물이 없습니다'));
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    try {
                      final post = PostModel.fromMap(
                        doc.data() as Map<String, dynamic>,
                        doc.id,
                      );
                      return _buildPostCard(post, doc);
                    } catch (e) {
                      print('Error building post card: $e');
                      return const SizedBox();
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24), // 하단 여백 추가
        ],
      ),
    );
  }

  Widget _buildPostCard(PostModel post, DocumentSnapshot doc) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: doc),
          ),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 8),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                child: post.imageUrls.isNotEmpty
                    ? Image.network(
                        post.imageUrls[0],
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 120,
                            color: Colors.grey[200],
                            child: const Icon(Icons.error),
                          );
                        },
                      )
                    : Container(
                        height: 120,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${post.likes}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(CupertinoIcons.bubble_left,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${post.comments}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:favorite_idol/firebase_options.dart';
import 'package:favorite_idol/providers/auth_provider.dart';
import 'package:favorite_idol/screens/auth/login_screen.dart';
import 'package:favorite_idol/screens/main/main_screen.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, FirebaseAuthException, User;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:favorite_idol/theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Firebase 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // AdMob 초기화
    try {
      await MobileAds.instance.initialize();
      print('AdMob initialized successfully');
    } catch (e) {
      print('AdMob initialization error: $e');
    }

    kakao.KakaoSdk.init(nativeAppKey: 'e14155adbc40823ab73f69ec8257ede4');

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        await auth.currentUser!.reload();
      }
    }
  } catch (e) {
    print('초기화 오류: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Favorite Idol App',
        theme: FATheme.lightTheme,
        home: const AuthStateHandler(),
      ),
    );
  }
}

class AuthStateHandler extends StatelessWidget {
  const AuthStateHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final user = snapshot.data;
            if (user == null) {
              // SharedPreferences 처리를 별도 함수로 분리
              _clearLoginState();
              return const LoginScreen();
            }

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const LoginScreen();
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                final isKakaoUser = userData?['isKakaoUser'] ?? false;

                if (isKakaoUser || user.emailVerified) {
                  return const MainScreen();
                }

                return const LoginScreen();
              },
            );
          },
        );
      },
    );
  }

  Future<void> _clearLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
    } catch (e) {
      print('Error clearing login state: $e');
    }
  }
}

class KakaoAuthService {
  static Future<User?> signInWithKakao() async {
    try {
      if (await kakao.AuthApi.instance.hasToken()) {
        try {
          await kakao.UserApi.instance.accessTokenInfo();
          kakao.User kakaoUser = await kakao.UserApi.instance.me();

          try {
            final credential =
                await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: '${kakaoUser.id}@kakao.com',
              password: 'kakao${kakaoUser.id}',
            );

            // SharedPreferences에 로그인 상태 저장
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isLoggedIn', true);

            return credential.user;
          } on FirebaseAuthException catch (e) {
            if (e.code == 'user-not-found') {
              final credential =
                  await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: '${kakaoUser.id}@kakao.com',
                password: 'kakao${kakaoUser.id}',
              );

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(credential.user?.uid)
                  .set({
                'email': '${kakaoUser.id}@kakao.com',
                'nickname': kakaoUser.kakaoAccount?.profile?.nickname ??
                    '카카오${kakaoUser.id}',
                'profileImage':
                    kakaoUser.kakaoAccount?.profile?.profileImageUrl ?? '',
                'createdAt': FieldValue.serverTimestamp(),
                'remainingVotes': 1,
                'isKakaoUser': true,
                'emailVerified': true,
              });

              // SharedPreferences에 로그인 상태 저장
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', true);

              return credential.user;
            }
          }
        } catch (e) {
          print('카카오 토큰 검증 실패: $e');
        }
      }
    } catch (e) {
      print('카카오 로그인 실패: $e');
    }
    return null;
  }
}

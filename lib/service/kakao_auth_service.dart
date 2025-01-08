import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:shared_preferences/shared_preferences.dart';

class KakaoAuthService {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;

  Future<auth.User?> signInWithKakao() async {
    try {
      // 기존 토큰이 있는지 확인
      if (await AuthApi.instance.hasToken()) {
        try {
          await UserApi.instance.accessTokenInfo();
          // 토큰이 유효하면 바로 사용자 정보 가져오기
          return await _getUserInfo();
        } catch (e) {
          // 토큰이 유효하지 않으면 재로그인
          await UserApi.instance.unlink();
        }
      }

      // 카카오톡 로그인
      if (await isKakaoTalkInstalled()) {
        await UserApi.instance.loginWithKakaoTalk();
      } else {
        await UserApi.instance.loginWithKakaoAccount();
      }

      // 사용자 정보 가져오기 전에 잠시 대기
      await Future.delayed(const Duration(milliseconds: 500));

      final user = await _getUserInfo();

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('loginType', 'kakao');
        await prefs.setString('userId', user.uid);

        // Firebase 인증 상태가 설정될 때까지 대기
        await Future.delayed(const Duration(seconds: 1));
      }

      return user;
    } catch (e) {
      print('카카오 로그인 실패: $e');
      // 에러 발생 시 모든 상태 초기화
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _firebaseAuth.signOut();
      return null;
    }
  }

  Future<auth.User?> _getUserInfo() async {
    try {
      User kakaoUser = await UserApi.instance.me();
      final email = '${kakaoUser.id}@kakao.com';
      final password = 'kakao${kakaoUser.id}';
      final nickname = kakaoUser.kakaoAccount?.profile?.nickname ?? 'User${kakaoUser.id}';

      try {
        // 기존 계정으로 로그인 시도
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // 로그인 성공 시 lastLoginAt 업데이트
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user?.uid)
            .update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });

        return credential.user;
      } on auth.FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // 새 계정 생성
          final credential = await _firebaseAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Firestore에 사용자 데이터 생성
          await FirebaseFirestore.instance
              .collection('users')
              .doc(credential.user?.uid)
              .set({
            'uid': credential.user?.uid,
            'email': email,
            'nickname': nickname,
            'profileImage': kakaoUser.kakaoAccount?.profile?.profileImageUrl ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'remainingVotes': 1,
            'isKakaoUser': true,
            'isAppleUser': false,
            'emailVerified': true,
            'lastLoginAt': FieldValue.serverTimestamp(),
          });

          return credential.user;
        }
        rethrow;
      }
    } catch (e) {
      print('사용자 정보 가져오기 실패: $e');
      return null;
    }
  }

  // 로그인 상태 확인
  Future<bool> checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final loginType = prefs.getString('loginType');

      if (isLoggedIn && loginType == 'kakao') {
        // 카카오 토큰 유효성 검사
        try {
          await UserApi.instance.accessTokenInfo();
          return true;
        } catch (e) {
          print('카카오 토큰 만료: $e');
          await _clearLoginState();
          return false;
        }
      }
      return false;
    } catch (e) {
      print('로그인 상태 확인 실패: $e');
      return false;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
      await _clearLoginState();
      await _firebaseAuth.signOut();
    } catch (e) {
      print('카카오 로그아웃 실패: $e');
    }
  }

  // 로그인 상태 제거
  Future<void> _clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('loginType');
    await prefs.remove('userId');
  }

  // 강제 로그아웃 (토큰 만료 등의 상황에서 사용)
  Future<void> forceSignOut() async {
    try {
      await _clearLoginState();
      await _firebaseAuth.signOut();
      try {
        await UserApi.instance.unlink();
      } catch (e) {
        print('카카오 연결 해제 실패: $e');
      }
    } catch (e) {
      print('강제 로그아웃 실패: $e');
    }
  }
}
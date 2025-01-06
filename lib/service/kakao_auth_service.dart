import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:http/http.dart' as http;

class KakaoAuthService {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;

  Future<auth.User?> signInWithKakao() async {
    try {
      // 카카오톡 실행 가능 여부 확인
      if (await isKakaoTalkInstalled()) {
        await UserApi.instance.loginWithKakaoTalk();
      } else {
        await UserApi.instance.loginWithKakaoAccount();
      }

      // 카카오 사용자 정보 가져오기
      auth.User? user = await _getUserInfo();
      return user;
    } catch (e) {
      print('카카오 로그인 실패: $e');
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
            'email': email,
            'nickname': nickname,
            'profileImage': kakaoUser.kakaoAccount?.profile?.profileImageUrl ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'remainingVotes': 1,
            'isKakaoUser': true,
            'emailVerified': true,
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
}
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

class AppleAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<User?> signInWithApple() async {
    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        print('Apple Sign In is not available on this device');
        return null;
      }

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      if (credential.identityToken == null) {
        throw 'Apple Sign In failed - no identity token';
      }

      // 이메일 중복 체크
      if (credential.email != null) {
        final methods = await _firebaseAuth.fetchSignInMethodsForEmail(credential.email!);
        if (methods.isNotEmpty && !methods.contains('apple.com')) {
          throw '이미 다른 방법으로 가입된 이메일입니다.';
        }
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken!,
        rawNonce: rawNonce,
        accessToken: credential.authorizationCode,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          String nickname;
          print('Creating new user...');

          if (credential.givenName != null || credential.familyName != null) {
            nickname = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
            print('Using Apple provided name: $nickname');
          } else {
            nickname = 'User${_generateRandomString(6)}';
            print('Generated random nickname: $nickname');
          }

          // 닉네임이 비어있는지 확인
          if (nickname.isEmpty) {
            nickname = 'User${_generateRandomString(6)}';
            print('Nickname was empty, generated new one: $nickname');
          }

          final userData = {
            'uid': user.uid,
            'email': credential.email ?? '${user.uid}@apple.com',
            'nickname': nickname,
            'profileImage': '',
            'createdAt': FieldValue.serverTimestamp(),
            'remainingVotes': 1,
            'isKakaoUser': false,
            'isAppleUser': true,
            'emailVerified': true,
            'lastLoginAt': FieldValue.serverTimestamp(),
          };

          print('Saving user data with nickname: ${userData['nickname']}');

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(userData);

          // 저장 후 확인
          final savedDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          print('Saved nickname: ${savedDoc.data()?['nickname']}');
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'lastLoginAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return user;
    } catch (e) {
      print('Apple sign in error: $e');
      return null;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
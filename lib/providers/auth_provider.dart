import 'dart:math';
import 'package:favorite_idol/service/kakao_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User, FirebaseAuthException;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  bool _initialized = false;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;

  AuthProvider() {
    _initializeAuthState();
  }

  Stream<UserModel?> get userModelStream {
    if (_user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(_user!.uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      _userModel = UserModel.fromMap(snapshot.data()!, snapshot.id);
      return _userModel;
    });
  }

  void _initializeAuthState() {
    _auth.authStateChanges().listen((user) async {
      try {
        _user = user;
        if (user != null) {
          final prefs = await SharedPreferences.getInstance();
          final loginType = prefs.getString('loginType');

          if (loginType == 'kakao') {
            try {
              await KakaoAuthService().checkLoginStatus();
            } catch (e) {
              await signOut();
              return;
            }
          }

          await loadUserData(user);
          await prefs.setBool('isLoggedIn', true);
        } else {
          _userModel = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
        }
        _initialized = true;
        notifyListeners();
      } catch (e) {
        print('Auth state change error: $e');
        _userModel = null;
        notifyListeners();
      }
    });
  }

  Future<void> loadUserData(User user) async {
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        print("Loaded user data: $data");

        if (data['nickname']?.toString().isEmpty ?? true) {
          final randomNickname = 'User${_generateRandomString(6)}';
          await _firestore.collection('users').doc(user.uid).update({
            'nickname': randomNickname
          });
          data['nickname'] = randomNickname;
        }
        _userModel = UserModel.fromMap(data, doc.id);
        await _updateLastLoginTime(user.uid);
        notifyListeners();
      }
    } catch (e) {
      print('Error loading user data: $e');
      _userModel = null;
      notifyListeners();
    }
  }

  Future<void> reloadUserData() async {
    if (_user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        _userModel = UserModel.fromMap(doc.data()!, doc.id);
        notifyListeners();
      }
    } catch (e) {
      print('Error reloading user data: $e');
    }
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _updateLastLoginTime(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last login time: $e');
    }
  }

  // 회원가입
  Future<String?> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return '회원가입에 실패했습니다.';

      final userModel = UserModel(
        uid: user.uid,
        email: email,
        nickname: nickname,
        profileImage: '',
        emailVerified: false,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users')
          .doc(user.uid)
          .set(userModel.toMap());

      await user.sendEmailVerification();

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return '이미 사용 중인 이메일입니다.';
        case 'weak-password':
          return '비밀번호가 너무 약합니다.';
        case 'invalid-email':
          return '잘못된 이메일 형식입니다.';
        default:
          return '회원가입 중 오류가 발생했습니다: ${e.message}';
      }
    } catch (e) {
      return '회원가입 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 로그인
  Future<String?> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return '로그인에 실패했습니다.';

      if (!user.emailVerified) {
        await _auth.signOut();
        return '이메일 인증이 완료되지 않았습니다.';
      }

      await loadUserData(user);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return '존재하지 않는 계정입니다.';
        case 'wrong-password':
          return '잘못된 비밀번호입니다.';
        case 'invalid-email':
          return '잘못된 이메일 형식입니다.';
        case 'user-disabled':
          return '비활성화된 계정입니다.';
        default:
          return '로그인 중 오류가 발생했습니다: ${e.message}';
      }
    } catch (e) {
      return '로그인 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 로그아웃
  Future<String?> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');

      if (_user != null) {
        await _updateLastLoginTime(_user!.uid);
      }

      await _auth.signOut();
      _user = null;
      _userModel = null;

      return null;
    } catch (e) {
      print('Logout error: $e');
      return '로그아웃 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();
}
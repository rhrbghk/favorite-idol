import 'package:favorite_idol/firebase_options.dart';
import 'package:favorite_idol/providers/auth_provider.dart';
import 'package:favorite_idol/screens/auth/login_screen.dart';
import 'package:favorite_idol/screens/main/main_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('Firebase initialized successfully');
    } else {
      Firebase.app();
      print('Using existing Firebase app');
    }
  } catch (e) {
    print('Firebase initialization error: $e');
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0XFF5f3d7a)),
          useMaterial3: true,
        ),
        home: Consumer<AuthProvider>(
          // 명시적으로 AuthProvider 타입 지정
          builder: (context, authProvider, _) {
            // 변수명도 더 명확하게 변경
            return StreamBuilder<auth.User?>(
              // User 타입 명시적 지정
              stream: auth.FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    authProvider.isLoading) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final user = snapshot.data;
                if (user != null && user.emailVerified) {
                  return const MainScreen();
                }

                return const LoginScreen();
              },
            );
          },
        ),
      ),
    );
  }
}
//머지 테스트

import 'package:favorite_idol/screens/chat/chat_list_screen.dart';
import 'package:favorite_idol/screens/home/home_screen.dart';
import 'package:favorite_idol/screens/profile/profile_screen.dart';
import 'package:favorite_idol/screens/search/search_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_alt_fill),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.camera_fill),
            label: '피드',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chat_bubble_2_fill),
            label: '채팅',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_crop_circle_fill),
            label: '프로필',
          ),
        ],
      ),
    );
  }
}

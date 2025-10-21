import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'workouts_page.dart';
import 'food_planner_page.dart';
import 'social_feed_page.dart';
import 'settings_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness App',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  // List of pages for the bottom nav bar
  static const List<Widget> _pages = <Widget>[
    DashboardPage(),
    WorkoutsPage(),
    FoodPlannerPage(),
    SocialFeedPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fitness App')),
      body: _pages[_selectedIndex], // show current page
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // allows more than 3 items
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workouts'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Food Planner'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Social Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
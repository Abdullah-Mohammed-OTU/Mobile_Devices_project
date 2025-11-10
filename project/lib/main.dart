import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/workouts_page.dart';
import 'pages/food_planner_page.dart';
import 'pages/social_feed_page.dart';
import 'pages/settings_page.dart';
import 'pages/login_page.dart';
import 'services/notifications_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _token;

  void _handleLogin(String token) {
    setState(() => _token = token);
  }

  void _handleLogout() {
    setState(() => _token = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness App',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: _token == null
          ? LoginPage(onLoginSuccess: _handleLogin)
          : MainPage(token: _token!, onLogout: _handleLogout),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.token, required this.onLogout});

  final String token;
  final VoidCallback onLogout;

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
      appBar: AppBar(
        title: const Text('Fitness App'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
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


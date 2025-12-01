import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/dashboard_page.dart';
import 'pages/workouts_page.dart';
import 'pages/food_planner_page.dart';
import 'pages/social_feed_page.dart';
import 'pages/settings_page.dart';
import 'pages/login_page.dart';
import 'services/notifications_service.dart';

// Global key and helper to allow other widgets to change the selected bottom tab.
final GlobalKey mainPageKey = GlobalKey();

/// Call to switch the bottom navigation index from other pages.
void navigateToBottomTab(int index) {
  try {
    final s = mainPageKey.currentState;
    if (s is _MainPageState) {
      s.setSelectedIndex(index);
    }
  } catch (e, st) {
    debugPrint('navigateToBottomTab error: $e');
    debugPrint(st.toString());
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  // load theme preference before running the app
  await ThemeNotifier.instance.load();
  runApp(const MyApp());
}

class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier._();
  static final ThemeNotifier instance = ThemeNotifier._();

  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('theme_mode') ?? 'light';
      if (s == 'dark') {
        _mode = ThemeMode.dark;
      } else if (s == 'system') {
        _mode = ThemeMode.system;
      } else {
        _mode = ThemeMode.light;
      }
    } catch (e) {
      _mode = ThemeMode.light;
      debugPrint('ThemeNotifier.load error: $e');
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = (m == ThemeMode.dark) ? 'dark' : (m == ThemeMode.system) ? 'system' : 'light';
      await prefs.setString('theme_mode', s);
    } catch (e, st) {
      debugPrint('ThemeNotifier.setMode save error: $e');
      debugPrint(st.toString());
    }
    notifyListeners();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _token;
  late VoidCallback _themeListener;

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
        ),
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textTheme: ThemeData.light().textTheme.apply(bodyColor: Colors.black87),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        scaffoldBackgroundColor: Colors.black,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey[850],
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.grey[900],
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      themeMode: ThemeNotifier.instance.mode,
        home: _token == null
          ? LoginPage(onLoginSuccess: _handleLogin)
          : MainPage(key: mainPageKey, token: _token!, onLogout: _handleLogout),
    );
  }

  @override
  void initState() {
    super.initState();
    _themeListener = () => setState(() {});
    ThemeNotifier.instance.addListener(_themeListener);
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_themeListener);
    super.dispose();
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
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      const DashboardPage(),
      const WorkoutsPage(),
      const FoodPlannerPage(),
      SocialFeedPage(),
      SettingsPage(onLogout: widget.onLogout),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Public setter used by `navigateToBottomTab` helper.
  void setSelectedIndex(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workouts'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Diet'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Social'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

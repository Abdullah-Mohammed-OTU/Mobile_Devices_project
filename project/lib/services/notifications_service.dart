import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _mainChannel = AndroidNotificationChannel(
    'main_channel',
    'Main Notifications',
    description: 'Notifications for workouts and meal planner',
    importance: Importance.high,
  );
  static const String _prefsKeyEnabled = 'notifications_enabled';
  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_mainChannel);
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefsKeyEnabled) ?? true;
  }
  NotificationDetails _details() {
    const androidDetails = AndroidNotificationDetails(
      'main_channel',
      'Main Notifications',
      channelDescription: 'Notifications for workouts and food planner',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    return const NotificationDetails(android: androidDetails);
  }
  int _newId() => DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyEnabled, _enabled);
    if (!_enabled) {
      await _plugin.cancelAll();
    }
  }

  Future<void> notifyWorkoutStart() async {
    if (!_enabled) return;
    await _plugin.show(
      _newId(),
      'Workout Started',
      'Timer running — let’s go!',
      _details(),
      payload: '/workouts',
    );
  }
  Future<void> notifyWorkoutComplete(int minutes) async {
    if (!_enabled) return;
    await _plugin.show(
      _newId(),
      'Workout Complete',
      'Nice work! $minutes minutes finished.',
      _details(),
      payload: '/workouts',
    );
  }
  Future<void> notifyFoodPlanner() async {
    if (!_enabled) return;
    await _plugin.show(
      _newId(),
      'Food Log Complete',
      'Congrats, You logged all your food for the day',
      _details(),
      payload: '/meals',
    );
  }
}

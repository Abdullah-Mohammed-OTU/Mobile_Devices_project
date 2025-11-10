import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_mainChannel);
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
  Future<void> notifyWorkoutStart() async {
    await _plugin.show(
      _newId(),
      'Workout Started',
      'Timer running — let’s go!',
      _details(),
      payload: '/workouts',
    );
  }
  Future<void> notifyWorkoutComplete(int minutes) async {
    await _plugin.show(
      _newId(),
      'Workout Complete',
      'Nice work! $minutes minutes finished.',
      _details(),
      payload: '/workouts',
    );
  }
  Future<void> notifyFoodPlanner() async {
    await _plugin.show(
      _newId(),
      'Food Planner',
      'Remember to get your meals on time!',
      _details(),
      payload: '/meals',
    );
  }
}


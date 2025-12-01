import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notifications_service.dart';
import '../services/macro_tracker.dart';
import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _loading = true;
  String _weightUnit = 'kg'; // 'kg' or 'lbs'

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = NotificationService.instance.enabled;
    _loading = false;
    _loadWeightUnit();
  }

  Future<void> _loadWeightUnit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final u = prefs.getString('weight_unit') ?? 'kg';
      setState(() {
        _weightUnit = u;
      });
    } catch (e, st) {
      debugPrint('Failed loading weight unit in settings: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _setWeightUnit(String unit) async {
    setState(() {
      _weightUnit = unit;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('weight_unit', unit);
    } catch (e, st) {
      debugPrint('Failed saving weight unit in settings: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    await NotificationService.instance.setEnabled(value);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await ThemeNotifier.instance.setMode(mode);
    setState(() {});
  }

  Future<void> _insertFakeWeek() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final histJson = prefs.getString('weight_history');
      final map = <String, double>{};
      if (histJson != null) {
        try {
          final decoded = jsonDecode(histJson) as Map<String, dynamic>;
          decoded.forEach((k, v) {
            final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
            map[k] = d;
          });
        } catch (e, st) {
          debugPrint('Error parsing existing weight_history in fake week insert: $e');
          debugPrint(st.toString());
        }
      }

      final base = prefs.getDouble('user_weight_kg') ?? 75.0;
      final today = DateTime.now();
      // create a gentle variation over 7 days
      for (int i = 6; i >= 0; i--) {
        final dt = today.subtract(Duration(days: i));
        final key = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        // small variation around base: -0.6 .. +0.6
        final weight = base + ((i - 3) * 0.2);
        map[key] = double.parse(weight.toStringAsFixed(1));
      }

      await prefs.setString('weight_history', jsonEncode(map));
      // set the default user weight to today's weight
      final todaysKey = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final todaysWeight = map[todaysKey] ?? base;
      await prefs.setDouble('user_weight_kg', todaysWeight);

      // Insert sample food totals for today into the MacroTracker (in-memory)
      try {
        final today = DateTime.now();
        // sample daily macros
        final sampleTotals = MacroTotals(calories: 2200, protein: 110, carbs: 260, fat: 70);
        MacroTracker.instance.setTotalsForDate(today, sampleTotals);
      } catch (e, st) {
        debugPrint('Failed inserting sample MacroTotals: $e');
        debugPrint(st.toString());
      }

      // Insert sample steps for today and yesterday into SharedPreferences
      try {
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        String fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final stepsMap = <String, int>{
          fmt(yesterday): 6200,
          fmt(today): 8400,
        };
        await prefs.setString('steps_history', jsonEncode(stepsMap));
      } catch (e, st) {
        debugPrint('Failed inserting sample steps_history: $e');
        debugPrint(st.toString());
      }

      if (mounted) {
        setState(() {
          _weightUnit = prefs.getString('weight_unit') ?? 'kg';
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserted sample weight week')));
      }
    } catch (e, st) {
      debugPrint('Failed _insertFakeWeek overall: $e');
      debugPrint(st.toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to insert sample data')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Notifications'),
                    subtitle: const Text('Enable workout and meal reminders'),
                    value: _notificationsEnabled,
                    onChanged: _loading ? null : _toggleNotifications,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: const Text('Weight units'),
                    subtitle: Text(_weightUnit == 'kg' ? 'Kilograms (kg)' : 'Pounds (lbs)'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('kg'),
                          value: 'kg',
                          groupValue: _weightUnit,
                          onChanged: (v) => _setWeightUnit(v ?? 'kg'),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('lbs'),
                          value: 'lbs',
                          groupValue: _weightUnit,
                          onChanged: (v) => _setWeightUnit(v ?? 'lbs'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: const Text('Theme'),
                    subtitle: Text(ThemeNotifier.instance.mode == ThemeMode.dark ? 'Dark' : 'Light'),
                  ),
                  Row(children: [
                    Expanded(
                      child: RadioListTile<ThemeMode>(
                        title: const Text('Light'),
                        value: ThemeMode.light,
                        groupValue: ThemeNotifier.instance.mode,
                        onChanged: (m) => _setThemeMode(m ?? ThemeMode.light),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<ThemeMode>(
                        title: const Text('Dark'),
                        value: ThemeMode.dark,
                        groupValue: ThemeNotifier.instance.mode,
                        onChanged: (m) => _setThemeMode(m ?? ThemeMode.dark),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: widget.onLogout,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.data_usage),
              title: const Text('Insert sample weight week'),
              subtitle: const Text('Populate your weight history with a week of example values'),
              onTap: () async {
                // confirm before inserting
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Insert sample data'),
                    content: const Text('This will add a week of example weight entries to your history. Continue?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Insert')),
                    ],
                  ),
                );
                if (ok == true) {
                  await _insertFakeWeek();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

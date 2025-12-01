import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notifications_service.dart';

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
    } catch (e) {}
  }

  Future<void> _setWeightUnit(String unit) async {
    setState(() {
      _weightUnit = unit;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('weight_unit', unit);
    } catch (e) {}
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    await NotificationService.instance.setEnabled(value);
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
        ],
      ),
    );
  }
}

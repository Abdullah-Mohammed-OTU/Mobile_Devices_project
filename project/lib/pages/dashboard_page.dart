import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/macro_tracker.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isTracking = false;
  int _steps = 0;
  DateTime _todayDate = DateTime.now();
  MacroTotals _todayTotals = MacroTotals.empty;
  late final VoidCallback _macroListener;

  @override
  void initState() {
    super.initState();
    _todayDate = _startOfToday();
    _todayTotals = MacroTracker.instance.totalsForDate(_todayDate);
    _macroListener = () {
      setState(() {
        _todayDate = _startOfToday();
        _todayTotals = MacroTracker.instance.totalsForDate(_todayDate);
      });
    };
    MacroTracker.instance.addListener(_macroListener);
  }

  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  //Gravity values
  double _gx = 0.0, _gy = 0.0, _gz = 0.0;
  final double _alpha = 0.8;

  double _lastMagnitude = 0.0;
  int _lastStepTimestamp = 0;
  final int _minStepIntervalMs = 300;
  final double _stepThreshold = 1.1;
  double _lastGyroMag = 0.0;

  void _toggleTracking() {
    if (_isTracking) {
      _stopTracking();
    } else {
      _startTracking();
    }
  }

  void _startTracking() {
    setState(() {
      _steps = 0;
      _lastMagnitude = 0.0;
      _lastStepTimestamp = 0;
    });

    _accSub = accelerometerEvents.listen(_onAccelerometerEvent, onError: (e) {});

    _gyroSub = gyroscopeEvents.listen(_onGyroscopeEvent, onError: (e) {});

    setState(() {
      _isTracking = true;
    });
  }

  void _stopTracking() {
    _accSub?.cancel();
    _accSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;

    setState(() {
      _isTracking = false;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Step tracking stopped'),
        content: Text('You took $_steps steps.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onGyroscopeEvent(GyroscopeEvent e) {
    _lastGyroMag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    //Gather gravity values, then remove it from the event values to get the actual movement values
    _gx = _alpha * _gx + (1 - _alpha) * event.x;
    _gy = _alpha * _gy + (1 - _alpha) * event.y;
    _gz = _alpha * _gz + (1 - _alpha) * event.z;

    final lx = event.x - _gx;
    final ly = event.y - _gy;
    final lz = event.z - _gz;


    final mag = sqrt(lx * lx + ly * ly + lz * lz);

    final now = DateTime.now().millisecondsSinceEpoch;
    final bool isRising = mag > _stepThreshold && _lastMagnitude <= _stepThreshold;
    final bool enoughTime = (now - _lastStepTimestamp) > _minStepIntervalMs;
    final bool gyroIndicatesMotion = _lastGyroMag > 0.05;

    if (isRising && enoughTime && gyroIndicatesMotion) {
      _lastStepTimestamp = now;
      _steps++;
      setState(() {});
    }

    _lastMagnitude = mag;
  }

  DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  void dispose() {
    MacroTracker.instance.removeListener(_macroListener);
    _accSub?.cancel();
    _gyroSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today: ${_formatDate(_todayDate)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Steps', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('$_steps', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          if (_isTracking)
                            const Text('(tracking)', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _toggleTracking,
                      child: Text(_isTracking ? 'Stop' : 'Start'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Today's macros", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Calories', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${_todayTotals.calories.toStringAsFixed(0)} cal'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Protein', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${_todayTotals.protein.toStringAsFixed(1)} g'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Carbs', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${_todayTotals.carbs.toStringAsFixed(1)} g'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fat', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${_todayTotals.fat.toStringAsFixed(1)} g'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/macro_tracker.dart';
import '../workout_api/workout_db.dart';
import '../main.dart';

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
  double _workoutCalories = 0.0;
  // weight history for dashboard card
  Map<String, double> _weightHistory = {};
  String _weightUnit = 'kg';
  // steps history per day (YYYY-MM-DD -> steps)
  Map<String, int> _stepsHistory = {};
  // user goal
  String _goal = '';
  final List<String> _goalOptions = [
    'Lose weight',
    'Maintain weight',
    'Gain muscle',
    'Increase endurance',
    'Improve flexibility',
    'General fitness',
  ];

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
    _loadCardOrder();
    _loadWorkoutCalories();
    _loadWeightHistory();
    _loadGoal();
    _loadStepsHistory();
  }

  Future<void> _loadStepsHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('steps_history');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        final map = <String, int>{};
        decoded.forEach((k, v) {
          map[k] = (v is int) ? v : int.tryParse('$v') ?? 0;
        });
        setState(() {
          _stepsHistory = map;
        });
      }
    } catch (e, st) {
      debugPrint('Failed loading steps_history: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _saveStepsHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('steps_history', jsonEncode(_stepsHistory));
    } catch (e, st) {
      debugPrint('Failed saving steps_history: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _loadGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('dashboard_goal');
      setState(() {
        if (saved != null && saved.isNotEmpty) {
          _goal = saved;
        } else {
          _goal = _goalOptions[1]; // default to 'Maintain weight'
        }
      });
    } catch (e, st) {
      debugPrint('Failed loading dashboard_goal: $e');
      debugPrint(st.toString());
      setState(() {
        _goal = _goalOptions[1];
      });
    }
  }

  Future<void> _saveGoal(String g) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dashboard_goal', g);
    } catch (e, st) {
      debugPrint('Failed saving dashboard_goal: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _loadWeightHistory() async {
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
          debugPrint('Failed parsing weight_history inner json: $e');
          debugPrint(st.toString());
        }
      }
      setState(() {
        _weightHistory = map;
        _weightUnit = prefs.getString('weight_unit') ?? 'kg';
      });
    } catch (e, st) {
      debugPrint('Failed loading weight_history: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _loadWorkoutCalories() async {
    try {
      final rows = await WorkoutDB.getWorkouts();
      double sum = 0.0;
      // Heuristic: if weight is stored, scale calories by weight; otherwise fall back to constant per-rep.
      // Formula: calories_per_rep = weightKg * 0.01 (e.g., 80kg -> 0.8 kcal/rep). If weight is 0 or missing,
      // fallback to 0.2 kcal/rep to avoid zeroing out older entries.
      for (final r in rows) {
        final int sets = (r['sets'] is int) ? r['sets'] as int : int.tryParse('${r['sets']}') ?? 0;
        final int reps = (r['reps'] is int) ? r['reps'] as int : int.tryParse('${r['reps']}') ?? 0;
        final double weightKg = (r['weight'] is num) ? (r['weight'] as num).toDouble() : double.tryParse('${r['weight']}') ?? 0.0;
        final double kcalPerRep = weightKg > 0 ? (weightKg * 0.01) : 0.2;
        sum += sets * reps * kcalPerRep;
      }
      setState(() {
        _workoutCalories = sum;
      });
    } catch (e, st) {
      debugPrint('Failed loading workout calories: $e');
      debugPrint(st.toString());
    }
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

    _accSub = accelerometerEvents.listen(_onAccelerometerEvent, onError: (e) {
      debugPrint('Accelerometer stream error: $e');
    });

    _gyroSub = gyroscopeEvents.listen(_onGyroscopeEvent, onError: (e) {
      debugPrint('Gyroscope stream error: $e');
    });

    setState(() {
      _isTracking = true;
    });
  }

  Future<void> _stopTracking() async {
    _accSub?.cancel();
    _accSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;

    setState(() {
      _isTracking = false;
    });

    // save today's steps into history
    try {
      final key = _formatDate(_startOfToday());
      _stepsHistory[key] = _steps;
      await _saveStepsHistory();
    } catch (e, st) {
      debugPrint('Failed saving todays steps: $e');
      debugPrint(st.toString());
    }

    if (!mounted) return;
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

  Future<void> _loadCardOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('dashboard_card_order');
      final defaultCards = ['goal', 'steps', 'macros', 'calories', 'weight_history'];
      if (saved != null && saved.isNotEmpty) {
        // keep user's saved order for known cards, but ensure all defaults exist
        final filtered = saved.where((s) => defaultCards.contains(s)).toList();
        final merged = <String>[];
        for (final s in filtered) {
          if (!merged.contains(s)) merged.add(s);
        }
        // Ensure 'goal' is at the top by default if user didn't include it
        if (!merged.contains('goal')) merged.insert(0, 'goal');
        // Append any remaining default cards (except 'goal' which we've already ensured)
        for (final d in defaultCards) {
          if (d == 'goal') continue;
          if (!merged.contains(d)) merged.add(d);
        }
        setState(() {
          _cardOrder = merged;
        });
      } else {
        setState(() {
          _cardOrder = List<String>.from(defaultCards);
        });
      }
    } catch (e) {
      // ignore loading errors, keep default order
    }
  }

  Future<void> _saveCardOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('dashboard_card_order', _cardOrder);
    } catch (e) {
      // ignore save errors
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reorderable list: maintain order of cards in state so users can drag to reorder

    Widget buildCard(int index, String id) {
      switch (id) {
        case 'goal':
          return Card(
            key: ValueKey(id),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle))),
                  const SizedBox(height: 8),
                  const Text('My goal is:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _goal.isNotEmpty ? _goal : null,
                    hint: const Text('Select a goal'),
                    isExpanded: true,
                    items: _goalOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _goal = val;
                      });
                      _saveGoal(val);
                    },
                  ),
                ],
              ),
            ),
          );
        case 'steps':
          return Card(
            key: ValueKey(id),
            child: InkWell(
              onTap: () => navigateToBottomTab(1),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Steps', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text('$_steps', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            if (_isTracking) const Text('(tracking)', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 6),
                            Builder(builder: (ctx) {
                              final yesterday = _formatDate(_startOfToday().subtract(const Duration(days: 1)));
                              final ySteps = _stepsHistory.containsKey(yesterday) ? _stepsHistory[yesterday] : 0;
                              return Text('Yesterday: ${ySteps ?? 0} steps', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65)));
                            }),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _toggleTracking,
                        child: Text(_isTracking ? 'Stop' : 'Start'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          );
        case 'macros':
          return Card(
            key: ValueKey(id),
            child: InkWell(
              onTap: () => navigateToBottomTab(2),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
                  ),
                  const SizedBox(height: 8),
                  const Text("Today's macros", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Calories', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${_todayTotals.calories.toStringAsFixed(0)} cal'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Protein', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${_todayTotals.protein.toStringAsFixed(1)} g'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Carbs', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${_todayTotals.carbs.toStringAsFixed(1)} g'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Fat', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${_todayTotals.fat.toStringAsFixed(1)} g'),
                    ],
                  ),
                ],
              ),
            ),
            ),
          );
        case 'calories':
          final caloriesIn = _todayTotals.calories;
          final caloriesOut = (_steps * 0.04) + _workoutCalories;
          final net = caloriesIn - caloriesOut;
          return Card(
            key: ValueKey(id),
            child: InkWell(
              onTap: () => navigateToBottomTab(2),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
                  ),
                  const SizedBox(height: 8),
                  // Left-aligned title to match other cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: const Text('Calories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Math-style equation: labels above numbers, operators aligned vertically
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        children: [
                          // Labels row (aligned with columns below)
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // In label
                                Expanded(flex: 3, child: Center(child: Text('In', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65))))),
                                const SizedBox(width: 8),
                                // spacer for operator
                                SizedBox(width: 28, child: Container()),
                                const SizedBox(width: 8),
                                // Out label
                                Expanded(flex: 3, child: Center(child: Text('Out', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65))))),
                                const SizedBox(width: 8),
                                // spacer for operator
                                SizedBox(width: 28, child: Container()),
                                const SizedBox(width: 8),
                                // Net label
                                Expanded(flex: 3, child: Center(child: Text('Net', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65))))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Numbers + operators row
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // In value
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    children: [
                                      FittedBox(fit: BoxFit.scaleDown, child: Text(caloriesIn.toStringAsFixed(0), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // minus
                                SizedBox(width: 28, child: FittedBox(fit: BoxFit.scaleDown, child: const Text('-', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)))),
                                const SizedBox(width: 8),
                                // Out value
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    children: [
                                      FittedBox(fit: BoxFit.scaleDown, child: Text(caloriesOut.toStringAsFixed(0), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // equals
                                SizedBox(width: 28, child: FittedBox(fit: BoxFit.scaleDown, child: const Text('=', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)))),
                                const SizedBox(width: 8),
                                // Net value
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    children: [
                                      FittedBox(fit: BoxFit.scaleDown, child: Text(net.toStringAsFixed(0), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: net >= 0 ? Colors.green : Colors.red))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            ),
          );
        case 'weight_history':
          // show recent weight entries and a small trend
          final entries = _weightHistory.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
          // only consider entries up to today
          final filtered = entries.where((e) {
            try {
              return DateTime.parse(e.key).isBefore(DateTime.now().add(const Duration(days: 1)));
            } catch (_) {
              return false;
            }
          }).toList();
          final recent = filtered.isEmpty ? <MapEntry<String, double>>[] : (filtered.length <= 7 ? filtered : filtered.sublist(filtered.length - 7));
          String? trendText;
          Color? trendColor;
          if (recent.length >= 2) {
            final first = recent.first.value;
            final last = recent.last.value;
            final deltaKg = last - first;
            final firstDate = DateTime.tryParse(recent.first.key) ?? DateTime.now();
            final lastDate = DateTime.tryParse(recent.last.key) ?? DateTime.now();
            var days = lastDate.difference(firstDate).inDays;
            if (days <= 0) days = 1;
            double displayDelta = deltaKg;
            String unitLabel = 'kg';
            if (_weightUnit != 'kg') {
              displayDelta = deltaKg * 2.2046226218;
              unitLabel = 'lbs';
            }
            final sign = displayDelta >= 0 ? '+' : '';
            trendText = '${sign}${displayDelta.toStringAsFixed(1)} $unitLabel over ${days}d';
            trendColor = displayDelta < 0 ? Colors.green : (displayDelta > 0 ? Colors.red : Colors.grey);
          }

          // build numeric list for sparkline (in user's unit)
          final recentVals = recent.map((e) => _weightUnit == 'kg' ? e.value : e.value * 2.2046226218).toList();

          return Card(
            key: ValueKey(id),
            child: InkWell(
              onTap: () => navigateToBottomTab(2),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle))),
                  const SizedBox(height: 8),
                  const Text('Weight', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (recent.isEmpty)
                    const Text('')
                  else ...[
                    // Sparkline showing recent values (most recent on right)
                    SizedBox(
                      height: 48,
                      child: _WeightSparkline(values: recentVals, lineColor: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    if (trendText != null)
                      Text('Trend: $trendText', style: TextStyle(color: trendColor, fontSize: 13)),
                  ],
                ],
              ),
            ),
            ),
          );
        default:
          return const SizedBox.shrink();
      }
    }

    return Scaffold(
      body: ReorderableListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(_cardOrder.length, (i) => buildCard(i, _cardOrder[i])),
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _cardOrder.removeAt(oldIndex);
            _cardOrder.insert(newIndex, item);
          });
          _saveCardOrder();
        },
      ),
    );
  }

  // order of dashboard cards (keys like 'goal','steps','macros','calories')
  List<String> _cardOrder = ['goal', 'steps', 'macros', 'calories'];
}

// Simple sparkline widget for weight values.
class _WeightSparkline extends StatelessWidget {
  final List<double> values;
  final Color lineColor;
  const _WeightSparkline({required this.values, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(values, lineColor),
      size: Size.infinite,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final minV = values.reduce(min);
    final maxV = values.reduce(max);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    final dx = values.length > 1 ? size.width / (values.length - 1) : size.width;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = dx * i;
      final norm = (values[i] - minV) / range;
      final y = size.height - (norm * size.height);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }

    // draw filled area under curve
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // draw line
    canvas.drawPath(path, paint);

    // draw a small dot on last point
    final lastX = dx * (values.length - 1);
    final lastNorm = (values.last - minV) / range;
    final lastY = size.height - (lastNorm * size.height);
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(Offset(lastX, lastY), 3.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return oldDelegate.color != color;
  }
}

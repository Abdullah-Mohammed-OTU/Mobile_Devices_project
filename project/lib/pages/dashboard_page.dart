import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/macro_tracker.dart';
import '../workout_api/workout_db.dart';

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
        } catch (e) {}
      }
      setState(() {
        _weightHistory = map;
        _weightUnit = prefs.getString('weight_unit') ?? 'kg';
      });
    } catch (e) {
      // ignore
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
    } catch (e) {
      // ignore errors and keep workout calories at 0
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

  Future<void> _loadCardOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('dashboard_card_order');
      if (saved != null && saved.isNotEmpty) {
        // validate keys
        final valid = ['steps', 'macros', 'calories', 'weight_history'];
        final filtered = saved.where((s) => valid.contains(s)).toList();
        if (filtered.isNotEmpty) {
          setState(() {
            _cardOrder = filtered;
          });
        }
      }
      // ensure weight_history card is present by default
      if (!_cardOrder.contains('weight_history')) {
        setState(() {
          _cardOrder.add('weight_history');
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
        case 'steps':
          return Card(
            key: ValueKey(id),
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
                  if (_workoutCalories > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Center(child: Text('Includes ${_workoutCalories.toStringAsFixed(0)} kcal from workouts', style: const TextStyle(fontSize: 12, color: Colors.black54))),
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
          );
        case 'macros':
          return Card(
            key: ValueKey(id),
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
          );
        case 'calories':
          final caloriesIn = _todayTotals.calories;
          final caloriesOut = (_steps * 0.04) + _workoutCalories;
          final net = caloriesIn - caloriesOut;
          return Card(
            key: ValueKey(id),
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
                                Expanded(flex: 3, child: Center(child: const Text('In', style: TextStyle(fontSize: 12, color: Colors.black54)))),
                                const SizedBox(width: 8),
                                // spacer for operator
                                SizedBox(width: 28, child: Container()),
                                const SizedBox(width: 8),
                                // Out label
                                Expanded(flex: 3, child: Center(child: const Text('Out', style: TextStyle(fontSize: 12, color: Colors.black54)))),
                                const SizedBox(width: 8),
                                // spacer for operator
                                SizedBox(width: 28, child: Container()),
                                const SizedBox(width: 8),
                                // Net label
                                Expanded(flex: 3, child: Center(child: const Text('Net', style: TextStyle(fontSize: 12, color: Colors.black54)))),
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

  // order of dashboard cards (keys like 'steps','macros','calories')
  List<String> _cardOrder = ['steps', 'macros', 'calories'];
}

// Simple sparkline widget for weight values.
class _WeightSparkline extends StatelessWidget {
  final List<double> values;
  final Color lineColor;
  const _WeightSparkline({required this.values, required this.lineColor, super.key});

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

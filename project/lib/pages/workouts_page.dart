import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notifications_service.dart';
import '../workout_api/exercise_api.dart';
import '../workout_api/exercise_model.dart';
import '../workout_api/workout_db.dart';
import '../services/workout_generator.dart';

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});
  @override
  State<WorkoutsPage> createState() => WorkoutsPageState();
}

class WorkoutsPageState extends State<WorkoutsPage> {
  Exercise? chosen;
  List<Exercise> apiExercises = [];
  List<Exercise> customExercises = [];
  List<String> saved = [];
  List<Map<String, dynamic>> recentWorkouts = [];
  List<Map<String, dynamic>> currentSession = [];
  String _weightUnit = 'kg';
  // Timed workout state
  Timer? _timedWorkoutTimer;
  Timer? _timedWorkoutTicker;
  int? _timedWorkoutMinutes;
  DateTime? _timedWorkoutEndTime;

  // NEW: AI plan holder
  Map<String, dynamic>? plan;

  // NEW: list of all exercise names used by the generator (keeps Choose Workout complete)
  // Keep in sync with WorkoutGenerator.generate() pools
  final List<String> aiExerciseNames = [
    // hypertrophy
    "Bench Press",
    "Incline DB Press",
    "Chest Fly",
    "Rows",
    "Lat Pulldown",
    "Face Pulls",
    "Shoulder Press",
    "Lateral Raises",
    "Rear Delt Fly",
    "Bicep Curls",
    "Tricep Extensions",
    "Squats",
    "Lunges",
    "RDL",
    "Leg Press",
    "Calf Raises",
    "Burpees",
    "Push-ups",
    "Squat Jumps",
    "Jump Rope",
    // strength / variations
    "Bench (5x5)",
    "Weighted Pull-up (5x5)",
    "OHP (5x5)",
    "Dips",
    "Squat (5x5)",
    "Deadlift (3x5)",
    "Hip Thrusts",
    "Calves",
    "Front Squats",
    "Plyo Lunges",
    // fat-loss / conditioning
    "Mountain Climbers",
    "High Knees",
    "Planks",
    // athletic
    "Power Cleans",
    "Box Jumps",
    "Sled Push",
    "Sprints",
    "Hanging Leg Raises",
    "Russian Twists",
  ];

  @override
  void initState() {
    super.initState();
    loadApiWorkouts();
    _loadCustomExercises();
    _loadRecentWorkouts();
    _loadUnit();
  }

  @override
  void dispose() {
    _timedWorkoutTimer?.cancel();
    _timedWorkoutTicker?.cancel();
    super.dispose();
  }

  void _startTimedWorkout(int minutes) async {
    // cancel existing
    _timedWorkoutTimer?.cancel();
    _timedWorkoutTicker?.cancel();
    _timedWorkoutMinutes = minutes;
    _timedWorkoutEndTime = DateTime.now().add(Duration(minutes: minutes));
    // notify start
    await NotificationService.instance.notifyWorkoutStart();

    // ticker to update UI every second
    _timedWorkoutTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });

    // schedule completion
    _timedWorkoutTimer = Timer(Duration(minutes: minutes), () async {
      try {
        await NotificationService.instance.notifyWorkoutComplete(minutes);
      } catch (_) {}
      _timedWorkoutMinutes = null;
      _timedWorkoutEndTime = null;
      _timedWorkoutTimer?.cancel();
      _timedWorkoutTicker?.cancel();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Timed workout complete ($minutes min)')));
      }
    });
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Timed workout started for $minutes minutes')));
    }
  }

  void _cancelTimedWorkout() {
    _timedWorkoutTimer?.cancel();
    _timedWorkoutTicker?.cancel();
    _timedWorkoutTimer = null;
    _timedWorkoutTicker = null;
    _timedWorkoutMinutes = null;
    _timedWorkoutEndTime = null;
    if (mounted) setState(() {});
  }

  String _formatRemaining(DateTime end) {
    final rem = end.difference(DateTime.now());
    if (rem.isNegative) return '0s';
    final h = rem.inHours;
    final m = rem.inMinutes % 60;
    final s = rem.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Future<void> _loadRecentWorkouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('recent_workouts');
      if (jsonStr == null) return;
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      setState(() =>
      recentWorkouts = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e, st) {
      debugPrint('Failed loading recent_workouts: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _saveRecentWorkouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('recent_workouts', jsonEncode(recentWorkouts));
    } catch (e, st) {
      debugPrint('Failed saving recent_workouts: $e');
      debugPrint(st.toString());
    }
  }

  // Add a new recent workout (list of exercise maps), keep only 5 unique entries
  Future<void> _addRecentWorkout(List<Map<String, dynamic>> exercises) async {
    try {
      final entry = {
        'exercises': exercises,
        'createdAt': DateTime.now().toIso8601String(),
      };
      // uniqueness by serialized exercises
      final serialized = jsonEncode(exercises);
      if (recentWorkouts.isNotEmpty) {
        final first = jsonEncode(recentWorkouts.first['exercises']);
        if (first == serialized) return; // duplicate of most recent
      }
      recentWorkouts.insert(0, entry);
      if (recentWorkouts.length > 5) recentWorkouts = recentWorkouts.sublist(0, 5);
      await _saveRecentWorkouts();
      setState(() {});
    } catch (e, st) {
      debugPrint('Error in _addRecentWorkout: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _reuseRecentWorkout(int index) async {
    if (index < 0 || index >= recentWorkouts.length) return;
    final entry = recentWorkouts[index];
    final List<dynamic> exs = entry['exercises'] as List<dynamic>;
    int inserted = 0;
    for (final e in exs) {
      try {
        final name = e['name']?.toString() ?? '';
        final sets = (e['sets'] is int) ? e['sets'] as int : int.tryParse('${e['sets']}') ?? 0;
        final reps = (e['reps'] is int) ? e['reps'] as int : int.tryParse('${e['reps']}') ?? 0;
        final weight = (e['weight'] is num) ? (e['weight'] as num).toDouble() : double.tryParse('${e['weight']}') ?? 0.0;
        await WorkoutDB.addWorkout(name, sets, reps, weight);
        final displayUnit = _weightUnit;
        final displayWeight = (displayUnit == 'kg') ? weight : (weight * 2.2046226218);
        saved.add("$name: ${sets}x$reps @ ${displayWeight.toStringAsFixed(1)}${displayUnit == 'kg' ? 'kg' : 'lbs'}");
        inserted++;
      } catch (e, st) {
        debugPrint('Failed reusing recent workout entry: $e');
        debugPrint(st.toString());
      }
    }
    if (inserted > 0) setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reused $inserted exercises from recent workout')));
    }
  }

  Future<void> _deleteRecentWorkout(int index) async {
    if (index < 0 || index >= recentWorkouts.length) return;
    recentWorkouts.removeAt(index);
    try {
      await _saveRecentWorkouts();
    } catch (e, st) {
      debugPrint('Failed deleting recent workout: $e');
      debugPrint(st.toString());
    }
    setState(() {});
  }

  void _removeFromSession(int index) {
    if (index < 0 || index >= currentSession.length) return;
    setState(() {
      currentSession.removeAt(index);
    });
  }

  Future<void> _addToSession(int sets, int reps, double weightKg) async {
    if (chosen == null) return;
    final exMap = {'name': chosen!.name, 'sets': sets, 'reps': reps, 'weight': weightKg};
    setState(() {
      currentSession.add(exMap);
    });
  }

  Future<void> _saveSession() async {
    if (currentSession.isEmpty) return;
    await _addRecentWorkout(List<Map<String, dynamic>>.from(currentSession));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session saved to Recent Workouts')));
  }

  Future<void> _logSession() async {
    if (currentSession.isEmpty) return;
    int inserted = 0;
    for (final e in List<Map<String, dynamic>>.from(currentSession)) {
      try {
        final name = e['name']?.toString() ?? '';
        final sets = (e['sets'] is int) ? e['sets'] as int : int.tryParse('${e['sets']}') ?? 0;
        final reps = (e['reps'] is int) ? e['reps'] as int : int.tryParse('${e['reps']}') ?? 0;
        final weight = (e['weight'] is num) ? (e['weight'] as num).toDouble() : double.tryParse('${e['weight']}') ?? 0.0;
        await WorkoutDB.addWorkout(name, sets, reps, weight);
        final displayUnit = _weightUnit;
        final displayWeight = (displayUnit == 'kg') ? weight : (weight * 2.2046226218);
        saved.add("$name: ${sets}x$reps @ ${displayWeight.toStringAsFixed(1)}${displayUnit == 'kg' ? 'kg' : 'lbs'}");
        inserted++;
      } catch (err, st) {
        debugPrint('Error logging session entry: $err');
        debugPrint(st.toString());
      }
    }
    if (inserted > 0) setState(() {});
    await _addRecentWorkout(List<Map<String, dynamic>>.from(currentSession));
    currentSession.clear();
    setState(() {});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logged $inserted exercises from session')));
  }

  Future<void> _loadCustomExercises() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('custom_exercises');
      if (jsonStr == null) return;
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      final list = decoded.map((e) {
        final m = e as Map<String, dynamic>;
        final name = m['name']?.toString() ?? 'Custom';
        final instr = <String>[];
        if (m['instructions'] is List) instr.addAll((m['instructions'] as List).map((x) => x.toString()));
        return Exercise(name: name, instructions: instr);
      }).toList();
      setState(() => customExercises = list);
    } catch (e, st) {
      debugPrint('Failed loading custom_exercises: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _saveCustomExercises() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = customExercises.map((ex) => {'name': ex.name, 'instructions': ex.instructions}).toList();
      await prefs.setString('custom_exercises', jsonEncode(list));
    } catch (e, st) {
      debugPrint('Failed saving custom_exercises: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _loadUnit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _weightUnit = prefs.getString('weight_unit') ?? 'kg';
      });
    } catch (e, st) {
      debugPrint('Failed loading weight_unit: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> loadApiWorkouts() async {
    try {
      List<Exercise> list = await ExerciseAPI.fetchExercises();
      setState(() {
        apiExercises = list.take(50).toList();
      });
    } catch (e, st) {
      debugPrint("API error: $e");
      debugPrint(st.toString());
    }
  }

  void pickWorkout() {
    // Build combined list: custom + api + AI exercises (deduped)
    final combined = <Exercise>[];
    final seen = <String>{};

    // add custom first
    for (final ex in customExercises) {
      if (!seen.contains(ex.name)) {
        seen.add(ex.name);
        combined.add(ex);
      }
    }

    // add api exercises
    for (final ex in apiExercises) {
      if (!seen.contains(ex.name)) {
        seen.add(ex.name);
        combined.add(ex);
      }
    }

    // add AI-only exercises converted to Exercise objects
    for (final name in aiExerciseNames) {
      if (!seen.contains(name)) {
        seen.add(name);
        combined.add(Exercise(name: name, instructions: ['No tips available']));
      }
    }

    if (combined.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Exercises not loaded yet")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("Select Workout"),
          children: [
            SimpleDialogOption(
              child: Row(children: const [Icon(Icons.add), SizedBox(width: 12), Text('Add Custom Exercise')]),
              onPressed: () {
                Navigator.pop(context);
                _showAddCustomExerciseDialog();
              },
            ),
            const Divider(),
            ...combined.map((ex) {
              return SimpleDialogOption(
                child: Text(ex.name),
                onPressed: () {
                  setState(() => chosen = ex);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        );
      },
    );
  }

  void logSetsReps() {
    if (chosen == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pick a workout first")));
      return;
    }
    TextEditingController setsC = TextEditingController();
    TextEditingController repsC = TextEditingController();
    TextEditingController weightC = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text("Log for ${chosen!.name}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: setsC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Sets"),
              ),
              TextField(
                controller: repsC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Reps"),
              ),
              TextField(
                controller: weightC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: "Weight (${_weightUnit == 'kg' ? 'kg' : 'lbs'})"),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(dialogCtx),
            ),
            TextButton(
              child: const Text("Save"),
              onPressed: () async {
                int? s = int.tryParse(setsC.text);
                int? r = int.tryParse(repsC.text);
                double entered = double.tryParse(weightC.text) ?? 0.0;
                if (s == null || r == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invalid numbers")),
                  );
                  return;
                }

                // Convert to kg for storage if user entered lbs
                double weightKg = entered;
                if (_weightUnit == 'lbs') {
                  weightKg = entered * 0.45359237;
                }

                await WorkoutDB.addWorkout(chosen!.name, s, r, weightKg);
                final exMap = {'name': chosen!.name, 'sets': s, 'reps': r, 'weight': weightKg};
                setState(() {
                  final displayUnit = _weightUnit;
                  saved.add("${chosen!.name}: ${s}x$r @ ${entered.toStringAsFixed(1)}${displayUnit == 'kg' ? 'kg' : 'lbs'}");
                });
                final navigator = Navigator.of(context);
                await _addRecentWorkout([exMap]);
                if (!mounted) return;
                navigator.pop();
              },
            ),
          ],
        );
      },
    );
  }

  void showTips() {
    if (chosen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pick a workout first")),
      );
      return;
    }

    List<String> tips = chosen!.instructions;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Tips for ${chosen!.name}"),
          content: tips.isEmpty
              ? const Text("No tips available for this exercise.")
              : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tips.map((t) => Text("- $t\n")).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Close"),
              onPressed: () => Navigator.pop(context),
            )
          ],
        );
      },
    );
  }


  void _showAddCustomExerciseDialog() {
    final nameC = TextEditingController();
    final instrC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Custom Exercise'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Exercise name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: instrC,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Instructions (one per line)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final name = nameC.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name required')));
                  return;
                }
                final instrLines = instrC.text
                    .split('\n')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                final ex = Exercise(name: name, instructions: instrLines);
                setState(() => customExercises.insert(0, ex));
                final navigator = Navigator.of(context);
                await _saveCustomExercises();
                if (!mounted) return;
                navigator.pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void showAIPopup() {
    String tempGoal = "hypertrophy";
    String tempDifficulty = "beginner";
    int tempDays = 4;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (ctx, setDlgState) {
          return AlertDialog(
            title: const Text("Generate AI Workout"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Goal"),
                const SizedBox(height: 6),
                DropdownButton<String>(
                  value: tempGoal,
                  items: const [
                    DropdownMenuItem(value: "hypertrophy", child: Text("Hypertrophy")),
                    DropdownMenuItem(value: "strength", child: Text("Strength")),
                    DropdownMenuItem(value: "fat_loss", child: Text("Fat Loss")),
                    DropdownMenuItem(value: "general_fitness", child: Text("General Fitness")),
                    DropdownMenuItem(value: "athletic_performance", child: Text("Athletic Performance")),
                  ],
                  onChanged: (v) => setDlgState(() => tempGoal = v!),
                ),
                const SizedBox(height: 8),
                const Text("Difficulty"),
                const SizedBox(height: 6),
                DropdownButton<String>(
                  value: tempDifficulty,
                  items: const [
                    DropdownMenuItem(value: "beginner", child: Text("Beginner")),
                    DropdownMenuItem(value: "intermediate", child: Text("Intermediate")),
                    DropdownMenuItem(value: "advanced", child: Text("Advanced")),
                  ],
                  onChanged: (v) => setDlgState(() => tempDifficulty = v!),
                ),
                const SizedBox(height: 8),
                const Text("Days per week"),
                const SizedBox(height: 6),
                DropdownButton<int>(
                  value: tempDays,
                  items: const [
                    DropdownMenuItem(value: 3, child: Text("3 days")),
                    DropdownMenuItem(value: 4, child: Text("4 days")),
                    DropdownMenuItem(value: 5, child: Text("5 days")),
                    DropdownMenuItem(value: 6, child: Text("6 days")),
                  ],
                  onChanged: (v) => setDlgState(() => tempDays = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: const Text("Generate"),
                onPressed: () {
                  // generate and close dialog
                  final result = WorkoutGenerator.generate(
                    goal: tempGoal,
                    daysPerWeek: tempDays,
                    difficulty: tempDifficulty,
                  );
                  setState(() => plan = result);
                  Navigator.pop(context);
                },
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: pickWorkout,
                        icon: const Icon(Icons.search),
                        label: Text(chosen?.name ?? 'Choose Workout'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: chosen == null
                            ? null
                            : () {
                          // Open a small dialog to add selected exercise to current session
                          final setsC = TextEditingController(text: '3');
                          final repsC = TextEditingController(text: '8');
                          final weightC = TextEditingController(text: '0');
                          showDialog(
                            context: context,
                            builder: (dctx) {
                              return AlertDialog(
                                title: Text('Add ${chosen!.name} to Session'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(controller: setsC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sets')),
                                    TextField(controller: repsC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reps')),
                                    TextField(controller: weightC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Weight (${_weightUnit == 'kg' ? 'kg' : 'lbs'})')),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () async {
                                      final s = int.tryParse(setsC.text) ?? 0;
                                      final r = int.tryParse(repsC.text) ?? 0;
                                      double entered = double.tryParse(weightC.text) ?? 0.0;
                                      double weightKg = entered;
                                      if (_weightUnit == 'lbs') weightKg = entered * 0.45359237;
                                      final navigator = Navigator.of(context);
                                      await _addToSession(s, r, weightKg);
                                      if (!mounted) return;
                                      navigator.pop();
                                    },
                                    child: const Text('Add'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('Add Selected to Session'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: logSetsReps,
                        icon: const Icon(Icons.edit),
                        label: const Text('Log Sets & Reps'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: showTips,
                        icon: const Icon(Icons.lightbulb),
                        label: const Text('Show Tips'),
                      ),
                      const SizedBox(height: 12),
                      // Timed workout controls
                      if (_timedWorkoutMinutes == null)
                        ElevatedButton.icon(
                          onPressed: () {
                            // choose minutes and start
                            showDialog<int>(
                              context: context,
                              builder: (dctx) {
                                int selected = 15;
                                String customText = '15';
                                final opts = [5, 10, 15, 20, 30, 45, 60];
                                return StatefulBuilder(
                                  builder: (ctx, setSt) {
                                    return AlertDialog(
                                      title: const Text('Start Timed Workout'),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ...opts.map((m) {
                                              return RadioListTile<int>(
                                                value: m,
                                                groupValue: selected,
                                                title: Text('$m minutes'),
                                                onChanged: (v) => setSt(() => selected = v ?? selected),
                                              );
                                            }).toList(),
                                            RadioListTile<int>(
                                              value: -1,
                                              groupValue: selected,
                                              title: Row(
                                                children: [
                                                  const Text('Custom'),
                                                  const SizedBox(width: 8),
                                                  if (selected == -1)
                                                    SizedBox(
                                                      width: 120,
                                                      child: TextField(
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(hintText: 'Minutes'),
                                                        onChanged: (v) => setSt(() => customText = v),
                                                        controller: TextEditingController(text: customText),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              onChanged: (v) => setSt(() => selected = v ?? selected),
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () {
                                            final minutes = selected == -1 ? int.tryParse(customText) : selected;
                                            if ((minutes ?? 0) <= 0) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid number of minutes')));
                                              return;
                                            }
                                            Navigator.pop(dctx, minutes);
                                          },
                                          child: const Text('Start'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ).then((minutes) {
                              if (minutes != null) _startTimedWorkout(minutes);
                            });
                          },
                          icon: const Icon(Icons.timer),
                          label: const Text('Timed Workout'),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _timedWorkoutEndTime == null
                                    ? 'Timed workout: $_timedWorkoutMinutes min'
                                    : 'Ends in ${_formatRemaining(_timedWorkoutEndTime!)}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _cancelTimedWorkout();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timed workout cancelled')));
                              },
                              child: const Text('Cancel'),
                            )
                          ],
                        ),
                      const SizedBox(height: 12),

                      ElevatedButton.icon(
                        onPressed: showAIPopup,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Generate AI Workout Plan'),
                      ),
                      const SizedBox(height: 12),

                    ],
                  ),
                ),
              ),

              // Show AI plan card (if plan is generated)
              if (plan != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AI Workout Plan', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        // show metadata
                        Text('Goal: ${plan!['goal'] ?? ''} • Difficulty: ${plan!['difficulty'] ?? ''} • Days: ${plan!['days'] ?? ''}'),
                        const SizedBox(height: 8),
                        // list days
                        Column(
                          children: (plan!['plan'] as List).map<Widget>((day) {
                            final exercises = (day['exercises'] as List).cast<String>();
                            return ListTile(
                              title: Text('${day['day']} — ${day['type']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: exercises.map((e) => Text('• $e')).toList(),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                // Save this plan as a recent workout (flatten plan into exercise entries)
                                final flat = <Map<String, dynamic>>[];
                                for (final d in (plan!['plan'] as List)) {
                                  for (final exStr in (d['exercises'] as List)) {
                                    // exStr is like "Bench Press — 3 sets x 8-12 reps"
                                    final parts = exStr.split('—');
                                    final name = parts[0].trim();
                                    flat.add({'name': name, 'sets': 0, 'reps': 0, 'weight': 0});
                                  }
                                }
                                _addRecentWorkout(flat);
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan saved to Recent Workouts')));
                              },
                              child: const Text('Save Plan to Recent'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                // regenerate with same settings if available
                                try {
                                  final g = plan!['goal'] as String;
                                  final d = plan!['difficulty'] as String;
                                  final days = plan!['days'] as int;
                                  final newPlan = WorkoutGenerator.generate(goal: g, daysPerWeek: days, difficulty: d);
                                  setState(() => plan = newPlan);
                                } catch (_) {
                                  // fallback: open popup
                                  showAIPopup();
                                }
                              },
                              child: const Text('Regenerate'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Recent saved workouts (reuse)
              if (recentWorkouts.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recent Workouts', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Column(
                          children: List.generate(recentWorkouts.length, (i) {
                            final entry = recentWorkouts[i];
                            final exs = (entry['exercises'] as List<dynamic>).cast<Map<String, dynamic>>();
                            final summary = exs.map((e) => '${e['name']} ${e['sets']}x${e['reps']}').join(', ');
                            final created = DateTime.tryParse(entry['createdAt'] ?? '') ?? DateTime.now();
                            return ListTile(
                              title: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${created.toLocal()}'),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteRecentWorkout(i)),
                                ElevatedButton(child: const Text('Reuse'), onPressed: () => _reuseRecentWorkout(i)),
                              ]),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              // Current session card
              if (currentSession.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Session', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Column(
                          children: List.generate(currentSession.length, (i) {
                            final e = currentSession[i];
                            return ListTile(
                              title: Text('${e['name']}'),
                              subtitle: Text('${e['sets']}x${e['reps']} @ ${(_weightUnit == 'kg' ? e['weight'] : (e['weight'] * 2.2046226218)).toStringAsFixed(1)} $_weightUnit'),
                              trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _removeFromSession(i)),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          ElevatedButton(onPressed: _saveSession, child: const Text('Save Session')),
                          const SizedBox(width: 8),
                          ElevatedButton(onPressed: _logSession, child: const Text('Log Session')),
                          const SizedBox(width: 8),
                          TextButton(onPressed: () { setState(() { currentSession.clear(); }); }, child: const Text('Clear')),
                        ])
                      ],
                    ),
                  ),
                ),

              // Logged workouts moved below the action card
              if (saved.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Logged Workouts', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(saved.join('\n')),
                      ],
                    ),
                  ),
                ),

            ],
          ),
        ),
      ),
    );
  }
}

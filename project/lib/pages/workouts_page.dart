import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// notifications_service not used here
import '../workout_api/exercise_api.dart';
import '../workout_api/exercise_model.dart';
import '../workout_api/workout_db.dart';

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
  @override
  void initState() {
    super.initState();
    loadApiWorkouts();
    _loadCustomExercises();
    _loadRecentWorkouts();
    _loadUnit();
  }

  Future<void> _loadRecentWorkouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('recent_workouts');
      if (jsonStr == null) return;
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      setState(() => recentWorkouts = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList());
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
    if (apiExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Exercises not loaded yet")),
      );
      return;
    }
    final combined = <Exercise>[];
    combined.addAll(customExercises);
    combined.addAll(apiExercises);

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
                    ],
                  ),
                ),
              ),

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
import 'package:flutter/material.dart';
import '../services/notifications_service.dart';
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
  List<String> saved = [];
  @override
  void initState() {
    super.initState();
    loadApiWorkouts();
  }

  Future<void> loadApiWorkouts() async {
    try {
      List<Exercise> list = await ExerciseAPI.fetchExercises();
      setState(() {
        apiExercises = list.take(50).toList();
      });
    }
    catch (e) {
      debugPrint("API error");
    }
  }

  void pickWorkout() {
    if (apiExercises.isEmpty) {
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
          children: apiExercises.map((ex) {
            return SimpleDialogOption(
              child: Text(ex.name),
              onPressed: () {
                setState(() => chosen = ex);
                Navigator.pop(context);
              },
            );
          }).toList(),
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
                if (s == null || r == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invalid numbers")),
                  );
                  return;
                }

                await WorkoutDB.addWorkout(chosen!.name, s, r);
                setState(() {
                  saved.add("${chosen!.name}: ${s}x$r");
                });
                Navigator.pop(dialogCtx);
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

  void startWorkoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Start Workout"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Pick how long you want to work out:"),
              const SizedBox(height: 12),
              ListTile(
                title: const Text("10 minutes"),
                onTap: () => _runTimedWorkout(ctx, 12),
              ),
              ListTile(
                title: const Text("20 minutes"),
                onTap: () => _runTimedWorkout(ctx, 20),
              ),
              ListTile(
                title: const Text("30 minutes"),
                onTap: () => _runTimedWorkout(ctx, 30),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(ctx),
            )
          ],
        );
      },
    );
  }

  Future<void> _runTimedWorkout(BuildContext dialogContext, int minutes) async {
    Navigator.pop(dialogContext);
    await NotificationService.instance.notifyWorkoutStart();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text("Workout started for $minutes minutes")));
    await Future.delayed(Duration(minutes: minutes));
    await NotificationService.instance.notifyWorkoutComplete(minutes);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Workout complete! ($minutes min)")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Workouts")),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (saved.isNotEmpty)
              Container(
                constraints: const BoxConstraints(
                  maxHeight: 150,
                ),
                child: Text(
                  "Logged Workouts:\n${saved.join("\n")}",
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.left,
                ),
              ),
            if (chosen != null) ...[
              const SizedBox(height: 12),
              Text(
                "Chosen Workout: ${chosen!.name}",
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.left,
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: pickWorkout,
                      child: const Text("Choose Workout"),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: logSetsReps,
                      child: const Text("Log Sets & Reps"),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: showTips,
                      child: const Text("Show Tips for Workout"),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: startWorkoutDialog,
                      child: const Text("Start Workout"),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
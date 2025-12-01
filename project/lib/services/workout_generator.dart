import 'dart:math';

class WorkoutGenerator {
  static final Random _rand = Random();

  /// Generates a randomized workout plan.
  /// goal: one of "hypertrophy", "strength", "fat_loss", "general_fitness", "athletic_performance"
  /// daysPerWeek: 3..6
  /// difficulty: "beginner" | "intermediate" | "advanced"
  static Map<String, dynamic> generate({
    required String goal,
    required int daysPerWeek,
    String difficulty = "beginner",
  }) {
    // Normalize / map goals to available pools
    final hypertrophyExercises = {
      "Chest": ["Bench Press", "Incline DB Press", "Chest Fly"],
      "Back": ["Rows", "Lat Pulldown", "Face Pulls"],
      "Shoulders": ["Shoulder Press", "Lateral Raises", "Rear Delt Fly"],
      "Arms": ["Bicep Curls", "Tricep Extensions"],
      "Legs": ["Squats", "Lunges", "RDL", "Leg Press", "Calf Raises"],
      "Full Body": ["Burpees", "Push-ups", "Squat Jumps"],
    };

    final strengthExercises = {
      "Upper": ["Bench (5x5)", "Weighted Pull-up (5x5)", "OHP (5x5)", "Dips"],
      "Lower": ["Squat (5x5)", "Deadlift (3x5)", "Hip Thrusts", "Calves"],
    };

    final weightLossExercises = {
      "Full Body": [
        "Burpees",
        "Squats",
        "Push-ups",
        "Mountain Climbers",
        "High Knees",
        "Planks"
      ]
    };

    // Map user-facing goals (List 2) into our internal pools
    Map<String, List<String>> selected;
    switch (goal) {
      case "strength":
        selected = strengthExercises;
        break;
      case "fat_loss":
        selected = weightLossExercises;
        break;
      case "general_fitness":
      // blend of hypertrophy + weight loss -> use hypertrophy + some full-body
        selected = Map.from(hypertrophyExercises);
        selected["Full Body"] = [
          ...?selected["Full Body"],
          "Burpees",
          "Mountain Climbers",
          "Jump Rope"
        ];
        break;
      case "athletic_performance":
      // use more dynamic/full-body work
        selected = {
          "Full Body": ["Power Cleans", "Box Jumps", "Sled Push", "Sprints"],
          "Legs": ["Front Squats", "Plyo Lunges", "RDL"],
          "Core": ["Hanging Leg Raises", "Russian Twists"]
        };
        break;
      default:
        selected = hypertrophyExercises;
    }

    // Difficulty determines sets and rep guidance
    int sets;
    String repRange;
    switch (difficulty) {
      case "intermediate":
        sets = 4;
        repRange = "6-10";
        break;
      case "advanced":
        sets = 5;
        repRange = "4-8";
        break;
      default:
        sets = 3;
        repRange = "8-12";
    }

    // Build plan with rotation + randomness
    List<Map<String, dynamic>> plan = [];
    final keys = selected.keys.toList();

    for (int i = 0; i < daysPerWeek; i++) {
      String dayType = keys[i % keys.length];

      // Shuffle a temporary list to get randomness
      List<String> allExercises = List.from(selected[dayType]!);
      allExercises.shuffle(_rand);

      // choose between 3-4 exercises depending on goal and difficulty
      int chooseCount = 3;
      if (difficulty == "advanced") chooseCount = 4;
      if (goal == "fat_loss" || goal == "general_fitness") chooseCount = 4;

      final chosenExercises = allExercises.take(chooseCount).map((e) {
        // Add sets/reps template
        return "$e — $sets sets x $repRange reps";
      }).toList();

      plan.add({
        "day": "Day ${i + 1}",
        "type": dayType,
        "exercises": chosenExercises,
      });
    }

    // If user picks many days, insert a rest day in the middle
    if (daysPerWeek >= 5) {
      plan.insert((plan.length / 2).floor(), {
        "day": "Rest Day",
        "type": "Rest",
        "exercises": ["Light stretching", "Mobility work - 10 min walk"]
      });
    }

    // Add a short "seed" note so plans vary per call (useful for debugging)
    return {
      "goal": goal,
      "difficulty": difficulty,
      "days": daysPerWeek,
      "plan": plan,
      "generated_at_seed": _rand.nextInt(999999), // helps show randomness
    };
  }
}
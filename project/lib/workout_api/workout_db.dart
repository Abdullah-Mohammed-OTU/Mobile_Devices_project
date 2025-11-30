import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class WorkoutDB {
  static Database? _db;
  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  static Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), "workouts.db");
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute("""
          CREATE TABLE workouts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exerciseName TEXT,
            sets INTEGER,
            reps INTEGER
          );"""
        );
      },
    );
  }

  static Future<int> addWorkout(String name, int sets, int reps) async {
    final database = await db;
    return await database.insert("workouts", {
      "exerciseName": name,
      "sets": sets,
      "reps": reps,
    });
  }

  static Future<List<Map<String, dynamic>>> getWorkouts() async {
    final database = await db;
    return await database.query("workouts");
  }
}

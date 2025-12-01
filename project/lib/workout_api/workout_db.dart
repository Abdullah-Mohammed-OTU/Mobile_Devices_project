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
      version: 2,
      onCreate: (Database db, int version) async {
        await db.execute("""
          CREATE TABLE workouts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exerciseName TEXT,
            sets INTEGER,
            reps INTEGER,
            weight REAL DEFAULT 0.0
          );"""
        );
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE workouts ADD COLUMN weight REAL DEFAULT 0.0');
          } catch (e) {
            // ignore errors (column may already exist)
          }
        }
      },
    );
  }

  static Future<int> addWorkout(String name, int sets, int reps, double weight) async {
    final database = await db;
    return await database.insert("workouts", {
      "exerciseName": name,
      "sets": sets,
      "reps": reps,
      "weight": weight,
    });
  }

  static Future<List<Map<String, dynamic>>> getWorkouts() async {
    final database = await db;
    return await database.query("workouts");
  }
}

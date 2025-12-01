import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Post {
  Post({this.id, this.username, this.content, this.dateAndTime});

  int? id;
  String? username;
  String? content;
  String? dateAndTime;

  Post.fromMap(Map<String, dynamic> map) {
    id = map['id'];
    username = map['username'];
    content = map['content'];
    dateAndTime = map['dateAndTime'];
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'content': content,
      'dateAndTime': dateAndTime,
    };
  }
}

class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController shortController = TextEditingController();

  List<Post> _posts = [];
  late Database database;
  bool dbLoaded = false;

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    var dbPath = await getDatabasesPath();
    String path = join(dbPath, 'mydatabase.db');

    database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute("""
          CREATE TABLE Post(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT,
            content TEXT,
            dateAndTime TEXT
          )
        """);
      },
    );

    await _loadPosts();
    setState(() => dbLoaded = true);
  }

  Future<void> _insertPost(Post newPost) async {
    await database.insert(
      'Post',
      newPost.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _loadPosts();
  }

  Future<List<Map<String, dynamic>>> _getPost() async {
    return await database.query(
      'Post',
      orderBy: "id DESC",
    );
  }

  Future<void> _deletePost(int id) async {
    await database.delete(
      'Post',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _loadPosts();
  }


  Future<void> _loadPosts() async {
    List<Map<String, dynamic>> records = await _getPost();
    _posts = records.map((map) => Post.fromMap(map)).toList();
    setState(() {});
  }

  @override
  void dispose() {
    nameController.dispose();
    shortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!dbLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Social Feed')),
      body: _posts.isEmpty
          ? const Center(
              child: Text(
                'Be the first to post!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.green,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(post.username ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(post.dateAndTime ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: post.id != null ? () => _deletePost(post.id!) : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(post.content ?? '', style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 12),
                        Row(
                          children: const [
                            Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 18),
                            SizedBox(width: 8),
                            Text('0'),
                            SizedBox(width: 16),
                            Icon(Icons.repeat, color: Colors.grey, size: 18),
                            SizedBox(width: 8),
                            Text('0'),
                            SizedBox(width: 16),
                            Icon(Icons.favorite_border, color: Colors.grey, size: 18),
                            SizedBox(width: 8),
                            Text('0'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Make a post'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Tell others about your progress, workout routine and more!',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: shortController,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter a username',
                        counterText: "",
                      ),
                    ),
                  ],
                ),

                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      final content = nameController.text.trim();
                      if (content.isEmpty) return;
                      final username = (shortController.text.trim().length > 1) ? shortController.text.trim() : 'User';
                      final newPost = Post(username: username, content: content, dateAndTime: DateTime.now().toString());
                      _insertPost(newPost);
                      nameController.clear();
                      shortController.clear();
                      Navigator.of(context).pop();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploaded')));
                    },
                    child: const Text('Post'),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
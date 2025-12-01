import 'package:flutter/material.dart';

final int a = 5;

class Post {
  Post({this.username, this.content, this.DateAndTime});

  String? username;
  String? content;
  String? DateAndTime;

  Post.fromMap(Map<String, dynamic> map) {
    username = map['username'];
    content = map['content'];
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'content': content,
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
  List<Post> _post = [];

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _post.isEmpty
          ? const Center(
              child: Text(
                'Be the first to post!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _post.length,
              itemBuilder: (context, index) {
                var post = _post[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
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
                                  Text(post.DateAndTime ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.more_horiz, color: Colors.grey),
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
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Make a post'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Tell others about your progress, workout routine and more!',
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
                      if (nameController.text.length > 1) {
                        var newPost = Post(username: "Person", content: nameController.text, DateAndTime: '${DateTime.now()}');
                        setState(() {
                          _post.add(newPost);
                          nameController.text = "";
                        });
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Uploaded')),
                        );
                      }
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

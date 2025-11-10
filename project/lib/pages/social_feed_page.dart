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
      appBar: AppBar(title: const Text('Social Feed')),
      body: _post.isEmpty
          ? const Center(
        child: Text(
          'Be the first to post!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      )
          : ListView.builder(
        itemCount: _post.length,
        itemBuilder: (context, index) {
          var post = _post[index];
          return ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.green,
              //child: const Text('MC'),
            ),
            title: Row(
              children: [
                Text(
                  "Username",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(width: 8),
                /*
                Text(
                  'shortname',
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                ),
                 */
                const SizedBox(width: 8),
                Text(
                  '${post.DateAndTime}',
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                ),
                const Spacer(),
                const Icon(Icons.expand_more, color: Colors.grey, size: 15),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  '${post.content}',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 15),
                    SizedBox(width: 4),
                    Text('0', style: TextStyle(fontSize: 15)),
                    SizedBox(width: 20),
                    Icon(Icons.repeat, color: Colors.grey, size: 15),
                    SizedBox(width: 4),
                    Text('0', style: TextStyle(fontSize: 15)),
                    SizedBox(width: 20),
                    Icon(Icons.favorite_border, color: Colors.grey, size: 15),
                    SizedBox(width: 4),
                    Text('0', style: TextStyle(fontSize: 15)),
                    SizedBox(width: 20),
                    Icon(Icons.bookmark_border, color: Colors.grey, size: 15),
                  ],
                ),
              ],
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
                        hintText:
                        'Tell others about your progress, workout routine and more!',
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
                        //print('User wrote: ${nameController.text}');
                        var newPost = Post(username: "Person",
                            content: nameController.text,
                            DateAndTime: '${DateTime.now()}');
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

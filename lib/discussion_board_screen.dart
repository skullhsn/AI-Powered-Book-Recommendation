import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DiscussionBoardScreen extends StatefulWidget {
  const DiscussionBoardScreen({super.key});

  @override
  _DiscussionBoardScreenState createState() => _DiscussionBoardScreenState();
}

class _DiscussionBoardScreenState extends State<DiscussionBoardScreen> {
  final _postController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion Board'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream:
                  FirebaseFirestore.instance
                      .collection('discussions')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No discussions yet.'));
                }

                return ListView(
                  padding: const EdgeInsets.all(10),
                  children:
                      snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        final content = data['content'] ?? '';
                        final userName = data['userName'] ?? '';
                        final userEmail = data['userEmail'] ?? 'Anonymous';

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(
                              content,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Posted by: ${userName.isNotEmpty ? userName : userEmail}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo,
                              child: Text(
                                (userName.isNotEmpty
                                        ? userName[0]
                                        : userEmail[0])
                                    .toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postController,
                    decoration: const InputDecoration(
                      labelText: 'Post a discussion',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.indigo,
                  onPressed: () async {
                    if (_postController.text.trim().isEmpty) return;

                    await FirebaseFirestore.instance
                        .collection('discussions')
                        .add({
                          'userId': user!.uid,
                          'userName': user?.displayName ?? '',
                          'userEmail': user?.email ?? 'Unknown',
                          'content': _postController.text.trim(),
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                    _postController.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DiscussionBoardScreen extends StatefulWidget {
  @override
  _DiscussionBoardScreenState createState() => _DiscussionBoardScreenState();
}

class _DiscussionBoardScreenState extends State<DiscussionBoardScreen> {
  final _postController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('Discussion Board')),
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
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                return ListView(
                  children:
                      snapshot.data!.docs.map((doc) {
                        return ListTile(
                          title: Text(doc['content']),
                          subtitle: Text('Posted by: ${doc['userId']}'),
                          onTap: () {
                            // Navigate to a detailed discussion view (to be implemented)
                          },
                        );
                      }).toList(),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postController,
                    decoration: InputDecoration(labelText: 'Post a discussion'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () async {
                    if (_postController.text.isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('discussions')
                          .add({
                            'userId': user!.uid,
                            'content': _postController.text,
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                      _postController.clear();
                    }
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

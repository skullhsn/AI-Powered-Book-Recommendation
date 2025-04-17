import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final book = ModalRoute.of(context)!.settings.arguments as Map;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(book['title'] ?? 'Book Details')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Title: ${book['title'] ?? 'No title'}',
              style: TextStyle(fontSize: 20),
            ),
            Text('Author: ${book['authors']?.join(', ') ?? 'Unknown'}'),
            Text('Description: ${book['description'] ?? 'No description'}'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('reading_list')
                    .add({
                      'title': book['title'],
                      'author': book['authors']?.join(', ') ?? 'Unknown',
                      'status': 'Want to Read',
                    });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added to Reading List')),
                );
              },
              child: Text('Add to Reading List'),
            ),
            ElevatedButton(
              onPressed: () {
                // Navigate to Submit Review Screen (to be implemented)
              },
              child: Text('Write a Review'),
            ),
          ],
        ),
      ),
    );
  }
}

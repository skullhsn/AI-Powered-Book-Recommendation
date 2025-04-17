import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubmitReviewScreen extends StatefulWidget {
  @override
  _SubmitReviewScreenState createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  final _reviewController = TextEditingController();
  double _rating = 0;

  @override
  Widget build(BuildContext context) {
    final book = ModalRoute.of(context)!.settings.arguments as Map;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('Write a Review')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review for: ${book['title']}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text('Rating:'),
            Slider(
              value: _rating,
              min: 0,
              max: 5,
              divisions: 5,
              label: _rating.toString(),
              onChanged: (value) {
                setState(() {
                  _rating = value;
                });
              },
            ),
            TextField(
              controller: _reviewController,
              decoration: InputDecoration(labelText: 'Your Review'),
              maxLines: 5,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_reviewController.text.isNotEmpty && _rating > 0) {
                  await FirebaseFirestore.instance.collection('reviews').add({
                    'userId': user!.uid,
                    'bookTitle': book['title'],
                    'bookAuthor': book['authors']?.join(', ') ?? 'Unknown',
                    'rating': _rating,
                    'review': _reviewController.text,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Review submitted!')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please provide a rating and review.'),
                    ),
                  );
                }
              },
              child: Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }
}

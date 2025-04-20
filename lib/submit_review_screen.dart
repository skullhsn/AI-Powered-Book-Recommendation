import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class SubmitReviewScreen extends StatefulWidget {
  @override
  _SubmitReviewScreenState createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  final _reviewController = TextEditingController();
  double _rating = 0.0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<bool> _hasUserReviewed(String? bookId, String userId) async {
    if (bookId == null || bookId.isEmpty || bookId == 'unknown') {
      print('Error: Invalid bookId for review check: $bookId'); // Debug log
      return false;
    }
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('reviews')
              .where('bookId', isEqualTo: bookId)
              .where('userId', isEqualTo: userId)
              .limit(1)
              .get();
      final hasReviewed = snapshot.docs.isNotEmpty;
      print(
        'Review check: bookId=$bookId, userId=$userId, hasReviewed=$hasReviewed',
      ); // Debug log
      return hasReviewed;
    } catch (e) {
      print('Error checking review: $e'); // Debug log
      return false; // Allow submission on error
    }
  }

  Future<void> _submitReview(Map<String, dynamic>? book) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to submit a review')),
      );
      return;
    }

    final reviewText = _reviewController.text.trim();
    if (reviewText.isEmpty || _rating == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a review and select a rating')),
      );
      return;
    }

    if (book == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: No book data provided')));
      return;
    }

    final bookId =
        book['id']?.toString() ?? book['volumeInfo']?['id']?.toString();
    if (bookId == null || bookId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: Invalid book data')));
      print('Error: No valid bookId for submission: $book'); // Debug log
      return;
    }

    // Check for existing review
    final hasReviewed = await _hasUserReviewed(bookId, user.uid);
    if (hasReviewed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have already submitted a review for this book'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      print(
        'Submitting review for book: ${book['title'] ?? 'Unknown'}, bookId: $bookId',
      ); // Debug log
      await FirebaseFirestore.instance.collection('reviews').add({
        'bookId': bookId,
        'bookTitle':
            book['title'] ?? book['volumeInfo']?['title'] ?? 'Unknown Title',
        'userId': user.uid,
        'userEmail': user.email ?? 'Anonymous',
        'review': reviewText,
        'rating': _rating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Review submitted successfully for bookId: $bookId'); // Debug log
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Review submitted successfully!')));

      Navigator.pop(context);
    } catch (e) {
      print('Error submitting review: $e'); // Debug log
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting review: $e')));
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get book details from route arguments with fallback
    final book =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    print('Book arguments received: $book'); // Debug log

    return Scaffold(
      appBar: AppBar(title: Text('Write a Review')),
      body:
          book == null
              ? Center(
                child: Text(
                  'Error: No book data available',
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
              )
              : Padding(
                padding: EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book['title'] ??
                            book['volumeInfo']?['title'] ??
                            'Unknown Title',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'by ${(book['authors'] ?? book['volumeInfo']?['authors'] ?? ['Unknown Author']).join(', ')}',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Rating',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      RatingBar.builder(
                        initialRating: 0,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
                        itemBuilder:
                            (context, _) =>
                                Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (rating) {
                          setState(() {
                            _rating = rating;
                          });
                          print('Rating updated: $_rating'); // Debug log
                        },
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Your Review',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _reviewController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Write your review here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                      SizedBox(height: 16),
                      _isSubmitting
                          ? Center(child: CircularProgressIndicator())
                          : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Colors.red,
                                  ), // Debug border
                                ),
                              ),
                              onPressed: () {
                                print(
                                  'Submit Review button pressed',
                                ); // Debug log
                                _submitReview(book);
                              },
                              child: Text(
                                'Submit Review',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
    );
  }
}

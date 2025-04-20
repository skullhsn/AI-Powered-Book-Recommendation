import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key});

  Future<bool> _hasUserReviewed(String bookId, String userId) async {
    if (bookId.isEmpty || bookId == 'unknown') {
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

  @override
  Widget build(BuildContext context) {
    final book = ModalRoute.of(context)!.settings.arguments as Map;
    final user = FirebaseAuth.instance.currentUser;

    // Extract bookId with multiple fallbacks
    final bookId =
        book['id']?.toString() ??
        book['volumeInfo']?['id']?.toString() ??
        book['bookId']?.toString() ??
        book['googleBooksId']?.toString() ??
        'unknown_${book['title']?.hashCode ?? DateTime.now().millisecondsSinceEpoch}';
    // Log full book data and keys
    print('BookDetailScreen received book: $book');
    print('Book keys: ${book.keys}');
    print('Extracted bookId: $bookId');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          book['title'] ?? book['volumeInfo']?['title'] ?? 'Book Details',
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book['imageLinks'] != null &&
                    book['imageLinks']['thumbnail'] != null ||
                book['volumeInfo']?['imageLinks']?['thumbnail'] != null)
              Center(
                child: Image.network(
                  book['imageLinks']?['thumbnail'] ??
                      book['volumeInfo']['imageLinks']['thumbnail'],
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) =>
                          Icon(Icons.book, size: 100),
                ),
              )
            else
              Center(child: Icon(Icons.book, size: 100)),
            SizedBox(height: 16),
            Text(
              book['title'] ?? book['volumeInfo']?['title'] ?? 'No Title',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'by ${(book['authors'] ?? book['volumeInfo']?['authors'] ?? ['Unknown Author']).join(', ')}',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              'Description',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              book['description'] ??
                  book['volumeInfo']?['description'] ??
                  'No description available',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            if (bookId.startsWith('unknown_'))
              Text(
                'Warning: Book ID is invalid, reviews may not display correctly',
                style: TextStyle(fontSize: 16, color: Colors.orange),
              ),
            SizedBox(height: 8),
            user == null
                ? Text(
                  'Sign in to add to reading list or write a review',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                )
                : Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          print(
                            'Add to Reading List button pressed',
                          ); // Debug log
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('reading_list')
                                .add({
                                  'title':
                                      book['title'] ??
                                      book['volumeInfo']?['title'] ??
                                      'No Title',
                                  'author': (book['authors'] ??
                                          book['volumeInfo']?['authors'] ??
                                          ['Unknown'])
                                      .join(', '),
                                  'status': 'Want to Read',
                                });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Added to Reading List')),
                            );
                          } catch (e) {
                            print(
                              'Error adding to reading list: $e',
                            ); // Debug log
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        child: Text(
                          'Add to Reading List',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    FutureBuilder<bool>(
                      future: _hasUserReviewed(bookId, user.uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          print(
                            'Error in FutureBuilder: ${snapshot.error}',
                          ); // Debug log
                          return Text(
                            'Error checking review status',
                            style: TextStyle(color: Colors.red),
                          );
                        }
                        final hasReviewed = snapshot.data ?? false;
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.blue,
                                ), // Debug border
                              ),
                              backgroundColor: hasReviewed ? Colors.grey : null,
                            ),
                            onPressed:
                                hasReviewed
                                    ? null
                                    : () {
                                      print(
                                        'Write a Review button pressed',
                                      ); // Debug log
                                      Navigator.pushNamed(
                                        context,
                                        '/submit_review',
                                        arguments: {
                                          'id': bookId,
                                          'title':
                                              book['title'] ??
                                              book['volumeInfo']?['title'] ??
                                              'Unknown Title',
                                          'authors':
                                              book['authors'] ??
                                              book['volumeInfo']?['authors'] ??
                                              ['Unknown Author'],
                                        },
                                      );
                                    },
                            child: Text(
                              hasReviewed
                                  ? 'Review Submitted'
                                  : 'Write a Review',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
            SizedBox(height: 20),
            Text(
              'Reviews',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('reviews')
                      .where('bookId', isEqualTo: bookId)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print(
                    'Error fetching reviews: ${snapshot.error}',
                  ); // Debug log
                  return Text(
                    'Error loading reviews: ${snapshot.error}',
                    style: TextStyle(color: Colors.red),
                  );
                }
                final reviews = snapshot.data?.docs ?? [];
                print(
                  'Fetched ${reviews.length} reviews for bookId: $bookId',
                ); // Debug log
                for (var review in reviews) {
                  print('Review: ${review.data()}'); // Debug log
                }
                if (reviews.isEmpty) {
                  return Text('No reviews yet', style: TextStyle(fontSize: 16));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '(${reviews.length} review${reviews.length == 1 ? '' : 's'})',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: reviews.length,
                      itemBuilder: (context, index) {
                        final review =
                            reviews[index].data() as Map<String, dynamic>;
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        review['userEmail'] ?? 'Anonymous',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    RatingBarIndicator(
                                      rating:
                                          (review['rating'] as num?)
                                              ?.toDouble() ??
                                          0.0,
                                      itemBuilder:
                                          (context, _) => Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                          ),
                                      itemCount: 5,
                                      itemSize: 20.0,
                                      direction: Axis.horizontal,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  review['review'] ?? '',
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _formatTimestamp(review['timestamp']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_book/api_service.dart';
import 'dart:math'; // For randomization
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingRecommendations = false;

  // Map user-friendly genres to Google Books API subjects
  static const Map<String, String> _genreToSubject = {
    'action': 'action adventure',
    'fiction': 'fiction',
    'sci-fi': 'science fiction',
    'fantasy': 'fantasy',
    'mystery': 'mystery',
    'romance': 'romance',
    'thriller': 'thriller',
    'horror': 'horror',
    'biography': 'biography',
    'history': 'history',
  };

  // Fallback book list for API failures
  static const List<Map<String, dynamic>> _fallbackBooks = [
    {
      'id': 'fallback_1',
      'volumeInfo': {
        'title': 'Fallback Action Book 1',
        'authors': ['Unknown Author'],
        'description': 'A placeholder action adventure book.',
        'imageLinks': {'thumbnail': 'https://via.placeholder.com/150'},
      },
    },
    {
      'id': 'fallback_2',
      'volumeInfo': {
        'title': 'Fallback Action Book 2',
        'authors': ['Unknown Author'],
        'description': 'Another placeholder action book.',
        'imageLinks': {'thumbnail': 'https://via.placeholder.com/150'},
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    // Fetch recommendations on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRecommendations();
    });
  }

  Future<void> _fetchRecommendations() async {
    setState(() {
      _isLoadingRecommendations = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Fetch user genres from Firestore
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final genres = List<String>.from(userDoc.data()?['genres'] ?? []);
      print('Fetched genres: $genres'); // Debug log

      // Use the first genre or default to 'fiction'
      final genre = genres.isNotEmpty ? genres[0].toLowerCase() : 'fiction';
      final apiQuery = _genreToSubject[genre] ?? genre;
      print('Using API query: subject:$apiQuery'); // Debug log

      // Fetch books for the genre
      List<dynamic> books;
      try {
        books = await ApiService.searchBooks(
          'subject:$apiQuery',
          maxResults: 20, // Fetch 20 for randomization variety
        );
        print('Fetched ${books.length} books: $books'); // Debug log
      } catch (e) {
        print('API call failed: $e'); // Debug log
        books = _fallbackBooks; // Use fallback books
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Using fallback books due to API error')),
        );
      }

      if (books.isEmpty) {
        throw Exception('No books found for genre: $genre');
      }

      // Randomly select up to 10 books (or fewer if less available)
      final random = Random();
      final maxBooks = books.length < 10 ? books.length : 10; // Increased to 10
      final selectedBooks = (books..shuffle(random)).take(maxBooks).toList();
      print(
        'Selected $maxBooks books for storage: $selectedBooks',
      ); // Debug log

      // Clear existing recommendations
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('recommended_books')
          .get()
          .then((snapshot) {
            for (var doc in snapshot.docs) {
              doc.reference.delete();
            }
          });

      // Add new recommendations to Firestore with full data
      for (var book in selectedBooks) {
        final volumeInfo = book['volumeInfo'] ?? {};
        final bookId =
            book['id']?.toString() ??
            volumeInfo['id']?.toString() ??
            'unknown_${volumeInfo['title']?.hashCode ?? random.nextInt(10000)}';
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('recommended_books')
            .add({
              'id': bookId,
              'title': volumeInfo['title'] ?? 'Unknown',
              'authors': volumeInfo['authors'] ?? ['Unknown Author'],
              'imageLinks': volumeInfo['imageLinks'] ?? {},
              'description':
                  volumeInfo['description'] ?? 'No description available',
              'volumeInfo': volumeInfo, // Store full volumeInfo for navigation
              'timestamp': FieldValue.serverTimestamp(),
            });
        print(
          'Stored book: id=$bookId, title=${volumeInfo['title']}',
        ); // Debug log
      }
    } catch (e) {
      print('Error fetching recommendations: $e'); // Debug log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load recommendations: $e')),
      );
    }
    setState(() {
      _isLoadingRecommendations = false;
    });
  }

  void _navigateToChat() {
    print('Navigating to ChatScreen'); // Debug log
    try {
      Navigator.pushNamed(context, '/chat').then((_) {
        print('Returned from ChatScreen'); // Debug log
      });
    } catch (e) {
      print('Navigation error: $e'); // Debug log
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to navigate to Chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text('Please log in to see recommendations.')),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header Row
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Book Recommendations',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Just For You',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _fetchRecommendations,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.deepPurpleAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurpleAccent.withOpacity(0.4),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Body content
            Expanded(
              child:
                  _isLoadingRecommendations
                      ? Center(child: CircularProgressIndicator())
                      : StreamBuilder(
                        stream:
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('recommended_books')
                                .orderBy('timestamp', descending: true)
                                .snapshots(),
                        builder: (
                          context,
                          AsyncSnapshot<QuerySnapshot> snapshot,
                        ) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('No recommendations yet.'),
                                  SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: _fetchRecommendations,
                                    child: Text('Load Recommendations'),
                                  ),
                                  SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: _navigateToChat,
                                    child: Text('Chat for Recommendations'),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              final doc = snapshot.data!.docs[index];
                              final bookData =
                                  doc.data() as Map<String, dynamic>;
                              return ListTile(
                                leading:
                                    bookData['imageLinks'] != null &&
                                            bookData['imageLinks']['thumbnail'] !=
                                                null
                                        ? Image.network(
                                          bookData['imageLinks']['thumbnail'],
                                          width: 50,
                                          errorBuilder:
                                              (ctx, obj, stk) =>
                                                  Icon(Icons.book, size: 50),
                                        )
                                        : Icon(Icons.book, size: 50),
                                title: Text(bookData['title'] ?? 'Unknown'),
                                subtitle: Text(
                                  bookData['authors']?.join(', ') ?? 'Unknown',
                                ),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/book_detail',
                                    arguments: {
                                      'id': bookData['id'],
                                      'title': bookData['title'],
                                      'authors': bookData['authors'],
                                      'imageLinks': bookData['imageLinks'],
                                      'description': bookData['description'],
                                      'volumeInfo': bookData['volumeInfo'],
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: false,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/search');
              break;
            case 1:
              Navigator.pushNamed(context, '/user_profile');
              break;
            case 2:
              Navigator.pushNamed(context, '/settings');
              break;
            case 3:
              _navigateToChat();
              break;
            case 4:
              Navigator.pushNamed(context, '/discussion_board');
              break;
          }
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Discussion'),
        ],
      ),
    );
  }
}

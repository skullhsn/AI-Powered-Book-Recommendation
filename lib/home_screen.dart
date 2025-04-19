import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';
import 'chat_screen.dart'; // Import the new chat screen

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingRecommendations = false;

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
      final genres = List<String>.from(
        userDoc.data()?['genres'] ?? ['fiction'],
      );

      // Use the first genre or default to 'fiction' for the API query
      final query = genres.isNotEmpty ? genres[0] : 'fiction';
      final books = await ApiService.searchBooks(query);

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

      // Add new recommendations to Firestore
      for (var book in books.take(5)) {
        final volumeInfo = book['volumeInfo'];
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('recommended_books')
            .add({
              'title': volumeInfo['title'] ?? 'Unknown',
              'author': volumeInfo['authors']?.join(', ') ?? 'Unknown',
              'imageLinks': volumeInfo['imageLinks'] ?? {},
              'timestamp': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
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
      // Handle unauthenticated state
      return Scaffold(
        body: Center(child: Text('Please log in to see recommendations.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Recommended Books'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
            tooltip: 'Search books',
          ),
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () => Navigator.pushNamed(context, '/reading_list'),
            tooltip: 'Reading list',
          ),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/user_profile'),
            tooltip: 'User profile',
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchRecommendations,
            tooltip: 'Refresh recommendations',
          ),
          IconButton(
            icon: Icon(Icons.question_answer),
            onPressed: _navigateToChat,
            tooltip: 'Ask about books',
          ),
        ],
      ),
      body: Stack(
        children: [
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
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    print('StreamBuilder error: ${snapshot.error}');
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                      return ListTile(
                        leading:
                            doc['imageLinks'] != null &&
                                    doc['imageLinks']['thumbnail'] != null
                                ? Image.network(
                                  doc['imageLinks']['thumbnail'],
                                  width: 50,
                                  errorBuilder:
                                      (ctx, obj, stk) =>
                                          Icon(Icons.book, size: 50),
                                )
                                : Icon(Icons.book, size: 50),
                        title: Text(doc['title'] ?? 'Unknown'),
                        subtitle: Text(doc['author'] ?? 'Unknown'),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/book_detail',
                            arguments: doc.data(),
                          );
                        },
                      );
                    },
                  );
                },
              ),
          // Chat button (floating action button)
          Positioned(
            right: 16.0,
            bottom: 16.0,
            child: FloatingActionButton(
              child: Icon(Icons.chat),
              tooltip: 'Chat for book recommendations',
              onPressed: _navigateToChat,
            ),
          ),
        ],
      ),
    );
  }
}
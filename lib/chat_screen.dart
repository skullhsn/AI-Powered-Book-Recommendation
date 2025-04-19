import 'package:flutter/material.dart';
import 'api_service.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _recommendedBooks = [];
  bool _isLoadingRecommendations = false;
  bool _isLoadingChatResponse = false;
  final List<Map<String, String>> _chatMessages = [
    {
      'sender': 'Bot',
      'message':
          'Hi! Ask me about books (e.g., "About Harry Potter") or type "recommend [genre]" for suggestions!',
    },
  ]; // Initialize with welcome message
  final Map<String, int> _genrePageIndex = {}; // Track page index for genres
  final Map<String, Set<String>> _recommendedBookIds =
      {}; // Track recommended book IDs

  @override
  void initState() {
    super.initState();
    // Scroll to bottom when new messages are added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _chatMessages.add({'sender': 'You', 'message': message});
    });

    // Scroll to bottom after adding user message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Handle recommendation request
    if (message.toLowerCase().contains('recommend')) {
      setState(() {
        _isLoadingRecommendations = true;
      });
      try {
        final query = message.toLowerCase().replaceAll('recommend', '').trim();
        final genre = query.isEmpty ? 'fiction' : query;

        // Initialize or increment page index for the genre
        _genrePageIndex[genre] =
            (_genrePageIndex[genre] ?? 0) + 10; // Increment by 10 for next page
        final startIndex =
            _genrePageIndex[genre]! -
            10; // Use previous page for current request

        // Initialize book ID set for the genre
        _recommendedBookIds[genre] ??= {};

        // Fetch books with pagination
        final books = await ApiService.searchBooks(
          genre,
          startIndex: startIndex,
        );

        // Filter out previously recommended books
        final newBooks =
            books.where((book) {
              final bookId = book['id'] as String;
              return !_recommendedBookIds[genre]!.contains(bookId);
            }).toList();

        // Update recommended book IDs
        newBooks.take(10).forEach((book) {
          _recommendedBookIds[genre]!.add(book['id'] as String);
        });

        setState(() {
          _recommendedBooks = newBooks.take(10).toList();
          _isLoadingRecommendations = false;
          if (_recommendedBooks.isEmpty) {
            _chatMessages.add({
              'sender': 'Bot',
              'message':
                  'No new books found for "$genre". Try a different genre or clear the chat!',
            });
          }
        });
      } catch (e) {
        setState(() {
          _chatMessages.add({
            'sender': 'Bot',
            'message': 'Error fetching recommendations: $e',
          });
          _isLoadingRecommendations = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching recommendations: $e')),
        );
      }
    } else {
      // Handle chatbot query
      setState(() {
        _isLoadingChatResponse = true;
      });
      try {
        String response;
        String searchQuery;

        // Simple query parsing
        final query = message.toLowerCase().trim();
        if (query.startsWith('about ') || query.contains('tell me about ')) {
          // Query for a specific book
          searchQuery = query
              .replaceFirst('about ', '')
              .replaceFirst('tell me about ', '');
          final books = await ApiService.searchBooks('intitle:$searchQuery');
          if (books.isNotEmpty) {
            final book = books[0]['volumeInfo'];
            response =
                'Here’s what I found about "${book['title']}":\n- Author(s): ${book['authors']?.join(', ') ?? 'Unknown'}\n- Description: ${book['description']?.substring(0, 100) ?? 'No description'}...';
          } else {
            response =
                'Sorry, I couldn’t find any books matching "$searchQuery". Try another title!';
          }
        } else if (query.contains('by ') || query.contains('books by ')) {
          // Query for books by an author
          searchQuery = query
              .replaceFirst('books by ', '')
              .replaceFirst('by ', '');
          final books = await ApiService.searchBooks('inauthor:$searchQuery');
          if (books.isNotEmpty) {
            final bookTitles = books
                .take(3)
                .map((b) => b['volumeInfo']['title'])
                .join(', ');
            response = 'Books by $searchQuery include: $bookTitles.';
          } else {
            response =
                'Sorry, I couldn’t find any books by "$searchQuery". Try another author!';
          }
        } else {
          // General search (assume genre or keyword)
          searchQuery = query;
          final books = await ApiService.searchBooks(searchQuery);
          if (books.isNotEmpty) {
            final bookTitles = books
                .take(3)
                .map((b) => b['volumeInfo']['title'])
                .join(', ');
            response =
                'I found these books related to "$searchQuery": $bookTitles.';
          } else {
            response =
                'Sorry, I couldn’t find any books related to "$searchQuery". Try another query!';
          }
        }

        setState(() {
          _chatMessages.add({'sender': 'Bot', 'message': response});
          _isLoadingChatResponse = false;
        });
      } catch (e) {
        setState(() {
          _chatMessages.add({'sender': 'Bot', 'message': 'Error: $e'});
          _isLoadingChatResponse = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching chatbot response: $e')),
        );
      }
    }

    _messageController.clear();
    // Scroll to bottom after adding bot response
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _clearChat() {
    setState(() {
      _chatMessages.clear();
      _recommendedBooks.clear();
      _genrePageIndex.clear(); // Reset page indices
      _recommendedBookIds.clear(); // Reset book ID cache
      _chatMessages.add({
        'sender': 'Bot',
        'message':
            'Hi! Ask me about books (e.g., "About Harry Potter") or type "recommend [genre]" for suggestions!',
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('AI Book Chatbot'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            tooltip: 'Clear Chat',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Recommendations
          if (_isLoadingRecommendations)
            Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          if (_recommendedBooks.isNotEmpty && !_isLoadingRecommendations)
            Container(
              height: 200,
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recommendedBooks.length,
                itemBuilder: (context, index) {
                  final book = _recommendedBooks[index]['volumeInfo'];
                  return Container(
                    width:
                        MediaQuery.of(context).size.width *
                        0.25, // Smaller responsive width
                    margin: EdgeInsets.only(right: 8.0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child:
                                  book['imageLinks'] != null &&
                                          book['imageLinks']['thumbnail'] !=
                                              null
                                      ? Image.network(
                                        book['imageLinks']['thumbnail'],
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Center(
                                                  child: Icon(
                                                    Icons.book,
                                                    size: 50,
                                                  ),
                                                ),
                                      )
                                      : Center(
                                        child: Icon(Icons.book, size: 50),
                                      ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book['title'] ?? 'No title',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  book['authors']?.join(', ') ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      textStyle: TextStyle(fontSize: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      print(
                                        'Details button pressed for: ${book['title']}',
                                      );
                                      Navigator.pushNamed(
                                        context,
                                        '/book_detail',
                                        arguments: book,
                                      );
                                    },
                                    child: Text('Details'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16.0),
              reverse: true,
              itemCount:
                  _chatMessages.length + (_isLoadingChatResponse ? 1 : 0),
              itemBuilder: (context, index) {
                // Handle loading indicator
                if (_isLoadingChatResponse && index == 0) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2),
                          SizedBox(width: 8),
                          Text('Thinking...'),
                        ],
                      ),
                    ),
                  );
                }
                // Handle chatbot messages
                final message = _chatMessages[_chatMessages.length - 1 - index];
                final isBot = message['sender'] == 'Bot';
                return Align(
                  alignment:
                      isBot ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isBot ? Colors.blue[50] : Colors.blue[200],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message['message']!,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          // Input field
          Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask about a book or type "recommend [genre]"',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
          'Hi! Ask me about books or type "recommend [genre]" for suggestions!',
    },
  ];
  final Map<String, int> _genrePageIndex = {};
  final Map<String, Set<String>> _recommendedBookIds = {};

  @override
  void initState() {
    super.initState();
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    if (message.toLowerCase().contains('recommend')) {
      setState(() {
        _isLoadingRecommendations = true;
      });

      try {
        final genre =
            message.toLowerCase().replaceAll('recommend', '').trim().isEmpty
                ? 'fiction'
                : message.toLowerCase().replaceAll('recommend', '').trim();

        _genrePageIndex[genre] = (_genrePageIndex[genre] ?? 0) + 10;
        final startIndex = _genrePageIndex[genre]! - 10;
        _recommendedBookIds[genre] ??= {};

        final books = await ApiService.searchBooks(
          genre,
          startIndex: startIndex,
        );

        final newBooks =
            books.where((book) {
              final bookId = book['id'] as String;
              return !_recommendedBookIds[genre]!.contains(bookId);
            }).toList();

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
                  'No new books found for "$genre". Try a different genre!',
            });
          }
        });
      } catch (e) {
        setState(() {
          _chatMessages.add({'sender': 'Bot', 'message': 'Error: $e'});
          _isLoadingRecommendations = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching recommendations')),
        );
      }
    } else {
      setState(() {
        _isLoadingChatResponse = true;
      });

      try {
        String response;
        String searchQuery;
        final query = message.toLowerCase().trim();

        if (query.startsWith('about ') || query.contains('tell me about ')) {
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
                'No books found for "$searchQuery". Try a different title!';
          }
        } else if (query.contains('by ') || query.contains('books by ')) {
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
            response = 'No books found by "$searchQuery". Try another author!';
          }
        } else {
          searchQuery = query;
          final books = await ApiService.searchBooks(searchQuery);
          if (books.isNotEmpty) {
            final bookTitles = books
                .take(3)
                .map((b) => b['volumeInfo']['title'])
                .join(', ');
            response = 'Books related to "$searchQuery": $bookTitles.';
          } else {
            response = 'No results for "$searchQuery". Try a different query!';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching response')));
      }
    }

    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _clearChat() {
    setState(() {
      _chatMessages.clear();
      _recommendedBooks.clear();
      _genrePageIndex.clear();
      _recommendedBookIds.clear();
      _chatMessages.add({
        'sender': 'Bot',
        'message':
            'Hi! Ask me about books or type "recommend [genre]" for suggestions!',
      });
    });
  }

  Widget _buildMessageBubble(Map<String, String> message) {
    final isBot = message['sender'] == 'Bot';
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6),
        padding: EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isBot
                    ? [Colors.blue.shade100, Colors.blue.shade50]
                    : [Colors.blueAccent.shade200, Colors.blue.shade300],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(message['message']!, style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildBookCard(dynamic bookInfo) {
    final book = bookInfo['volumeInfo'];
    return Container(
      width: 140,
      margin: EdgeInsets.only(right: 12),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                child:
                    book['imageLinks'] != null
                        ? Image.network(
                          book['imageLinks']['thumbnail'],
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                        : Container(
                          color: Colors.grey[300],
                          child: Icon(Icons.book, size: 48),
                        ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book['title'] ?? 'No title',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    book['authors']?.join(', ') ?? 'Unknown',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/book_detail',
                        arguments: book,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      textStyle: TextStyle(fontSize: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Details'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigoAccent, Colors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text('AI Book Chatbot'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _clearChat)],
      ),
      body: Column(
        children: [
          if (_isLoadingRecommendations)
            Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          if (_recommendedBooks.isNotEmpty && !_isLoadingRecommendations)
            Container(
              height: 220,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recommendedBooks.length,
                itemBuilder:
                    (context, index) =>
                        _buildBookCard(_recommendedBooks[index]),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              reverse: true,
              itemCount:
                  _chatMessages.length + (_isLoadingChatResponse ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoadingChatResponse && index == 0) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
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
                final message = _chatMessages[_chatMessages.length - 1 - index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type message...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
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

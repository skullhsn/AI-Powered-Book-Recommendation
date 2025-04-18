import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _messages = [];

  // DeepSeek API configuration
  // Replace with your actual API key
  final String _apiKey =
      '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';
  final String _apiUrl = 'https://api.deepseek.com/v1';

  // Fallback to use if DeepSeek fails (this is a mock function)
  Future<String> _getLocalResponse(String userMessage) async {
    // Simple keyword-based response system as fallback
    final userMessageLower = userMessage.toLowerCase();

    if (userMessageLower.contains('recommend') ||
        userMessageLower.contains('suggestion') ||
        userMessageLower.contains('book')) {
      return "I'd recommend checking out 'Project Hail Mary' by Andy Weir if you enjoy sci-fi, or 'The Lincoln Highway' by Amor Towles for literary fiction. Would you like more specific recommendations based on your interests?";
    } else if (userMessageLower.contains('hello') ||
        userMessageLower.contains('hi') ||
        userMessageLower.contains('hey')) {
      return "Hello! I'm your book recommendation assistant. I can help you find books based on your interests, genres you enjoy, or specific themes you're looking for. What kind of books do you enjoy reading?";
    } else if (userMessageLower.contains('thank')) {
      return "You're welcome! Feel free to ask if you need more book recommendations or have any questions about books.";
    } else {
      return "I'm here to help you find great books to read. Could you tell me what genres or themes you're interested in, or what kind of book you're looking for?";
    }
  }

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final chatHistory =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('chat_history')
                .orderBy('timestamp')
                .get();

        setState(() {
          _messages =
              chatHistory.docs
                  .map(
                    (doc) => {
                      'content': doc['content'],
                      'isUser': doc['isUser'],
                      'timestamp': doc['timestamp'],
                    },
                  )
                  .toList();
        });
      } catch (e) {
        print('Error loading chat history: $e');
        // Show a snackbar with the error
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load chat history')));
      }
    }
  }

  Future<void> _saveChatMessage(String message, bool isUser) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('chat_history')
            .add({
              'content': message,
              'isUser': isUser,
              'timestamp': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        print('Error saving chat message: $e');
        // We don't show an error to the user here as it would disrupt the chat flow
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text;
    _messageController.clear();

    setState(() {
      _messages.add({
        'content': userMessage,
        'isUser': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      _isLoading = true;
    });

    await _saveChatMessage(userMessage, true);
    _scrollToBottom();

    try {
      // Try to get response from DeepSeek API
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': 'deepseek-chat',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a helpful book recommendation assistant that helps users find books based on their interests and preferences. Provide specific book titles, authors, and brief descriptions of why the user might enjoy them.',
                },
                {'role': 'user', 'content': userMessage},
              ],
              'max_tokens': 500,
            }),
          )
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              // If the request times out, throw an exception
              throw TimeoutException('The request timed out');
            },
          );

      String aiResponse;

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          aiResponse = data['choices'][0]['message']['content'];
        } catch (e) {
          print('Error parsing API response: $e');
          print('Response body: ${response.body}');
          // Fall back to local response
          aiResponse = await _getLocalResponse(userMessage);
        }
      } else {
        print('API error: ${response.statusCode} - ${response.body}');
        // Fall back to local response
        aiResponse = await _getLocalResponse(userMessage);
      }

      setState(() {
        _messages.add({
          'content': aiResponse,
          'isUser': false,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        _isLoading = false;
      });

      await _saveChatMessage(aiResponse, false);
      _scrollToBottom();
    } catch (e) {
      print('Exception during API call: $e');

      // Get a fallback response
      final fallbackResponse = await _getLocalResponse(userMessage);

      setState(() {
        _messages.add({
          'content': fallbackResponse,
          'isUser': false,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        _isLoading = false;
      });

      await _saveChatMessage(fallbackResponse, false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Book Assistant'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text('Clear Chat History'),
                      content: Text(
                        'Are you sure you want to clear the chat history?',
                      ),
                      actions: [
                        TextButton(
                          child: Text('Cancel'),
                          onPressed: () => Navigator.pop(context),
                        ),
                        TextButton(
                          child: Text('Clear'),
                          onPressed: () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              try {
                                final batch =
                                    FirebaseFirestore.instance.batch();
                                final chats =
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .collection('chat_history')
                                        .get();

                                for (final doc in chats.docs) {
                                  batch.delete(doc.reference);
                                }

                                await batch.commit();
                                setState(() {
                                  _messages = [];
                                });
                                Navigator.pop(context);
                              } catch (e) {
                                print('Error clearing chat history: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to clear chat history',
                                    ),
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            }
                          },
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _messages.isEmpty
                    ? _buildWelcomeMessage()
                    : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(10),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return Align(
                          alignment:
                              message['isUser']
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 5),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  message['isUser']
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[300],
                              borderRadius: BorderRadius.circular(15),
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            child: Text(
                              message['content'],
                              style: TextStyle(
                                color:
                                    message['isUser']
                                        ? Colors.white
                                        : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Getting book recommendations...'),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask for book recommendations...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: EdgeInsets.all(12),
                    ),
                    minLines: 1,
                    maxLines: 5,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 10),
                FloatingActionButton(
                  mini: true,
                  onPressed: _sendMessage,
                  child: Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          SizedBox(height: 20),
          Text(
            'Welcome to AI Book Assistant',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Ask for book recommendations based on your interests, favorite authors, or genres you enjoy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          SizedBox(height: 30),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Example questions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 10),
          _buildExampleQuestionChip('Recommend sci-fi books like Dune'),
          _buildExampleQuestionChip('Books similar to Harry Potter'),
          _buildExampleQuestionChip('Best mystery novels of 2024'),
        ],
      ),
    );
  }

  Widget _buildExampleQuestionChip(String question) {
    return GestureDetector(
      onTap: () {
        _messageController.text = question;
        _sendMessage();
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5),
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(question),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}

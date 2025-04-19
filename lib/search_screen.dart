import 'package:flutter/material.dart';
import 'api_service.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _books = [];
  bool _isLoading = false;

  Future<void> _searchBooks(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final books = await ApiService.searchBooks(query);
      setState(() {
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search Books')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by title, author, or genre',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => _searchBooks(_searchController.text),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _books.length,
              itemBuilder: (context, index) {
                final book = _books[index]['volumeInfo'];
                return ListTile(
                  title: Text(book['title'] ?? 'No title'),
                  subtitle: Text(
                    book['authors']?.join(', ') ?? 'Unknown author',
                  ),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/book_detail',
                      arguments: book,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

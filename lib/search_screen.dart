import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _books = [];

  Future<void> _searchBooks(String query) async {
    final url = 'https://www.googleapis.com/books/v1/volumes?q=$query';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _books = data['items'] ?? [];
      });
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

import 'package:flutter/material.dart';
import 'api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

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
      appBar: AppBar(
        title: Text(
          'Search Books',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by title, author, or genre',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.search,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: () => _searchBooks(_searchController.text),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            if (_isLoading) Center(child: CircularProgressIndicator()),
            if (!_isLoading)
              Expanded(
                child:
                    _books.isEmpty
                        ? Center(
                          child: Text(
                            'No results',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                        : ListView.separated(
                          itemCount: _books.length,
                          separatorBuilder: (_, __) => SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final book = _books[index]['volumeInfo'];
                            return InkWell(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/book_detail',
                                  arguments: book,
                                );
                              },
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        book['title'] ?? 'No title',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        book['authors']?.join(', ') ??
                                            'Unknown author',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
              ),
          ],
        ),
      ),
    );
  }
}

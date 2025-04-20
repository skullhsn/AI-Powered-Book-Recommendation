import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String? get _apiKey => dotenv.env['GOOGLE_BOOKS_API_KEY'];
  static const String _baseUrl = 'https://www.googleapis.com/books/v1/volumes';

  static Future<List<dynamic>> searchBooks(
    String query, {
    int startIndex = 0,
    int maxResults = 20, // Align with home_screen.dart
  }) async {
    if (_apiKey == null) {
      throw Exception('Google Books API key not found in .env file');
    }
    final url =
        '$_baseUrl?q=${Uri.encodeQueryComponent(query)}&key=$_apiKey&startIndex=$startIndex&maxResults=$maxResults';
    try {
      print('API Request URL: $url'); // Debug log
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        print('API Response: ${items.length} books returned'); // Debug log
        print(
          'First item: ${items.isNotEmpty ? items[0] : 'none'}',
        ); // Debug log
        return items;
      } else {
        throw Exception(
          'Failed to fetch books: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching books: $e'); // Debug log
      throw Exception('Error fetching books: $e');
    }
  }

  static Future<Map<String, dynamic>> getBookDetails(String bookId) async {
    if (_apiKey == null) {
      throw Exception('Google Books API key not found in .env file');
    }
    final url = '$_baseUrl/$bookId?key=$_apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to fetch book details: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching book details: $e');
    }
  }
}

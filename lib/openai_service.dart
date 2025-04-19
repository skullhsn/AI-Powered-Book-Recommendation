/**import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static String get openAIApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String openAIUrl = 'https://api.openai.com/v1/chat/completions';
  static const String googleBooksUrl =
      'https://www.googleapis.com/books/v1/volumes';

  // Fetch user genres from Firestore
  static Future<List<String>> _getUserGenres() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No authenticated user found');
      return [];
    }
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (!doc.exists) {
        print('User document does not exist for user: ${user.uid}');
        return [];
      }
      final genresData = doc['genres'] ?? [];
      if (genresData is List) {
        final genres = genresData.map((item) => item.toString()).toList();
        print('User genres: $genres');
        return genres;
      } else {
        print('Genres field is not a list: $genresData');
        return [];
      }
    } catch (e) {
      print('Error fetching user genres: $e');
      return [];
    }
  }

  // Generate book recommendations using OpenAI
  static Future<List<Map<String, dynamic>>> getBookRecommendations() async {
    try {
      // Check if dotenv is initialized
      if (!dotenv.isInitialized) {
        print(
          'flutter_dotenv not initialized. Using fallback recommendations.',
        );
        final fallback = [
          {
            'title': 'The Bourne Identity',
            'authors': ['Robert Ludlum'],
            'description':
                'An action-packed thriller about a man with no memory.',
            'imageLinks': {},
          },
          {
            'title': 'Die Hard',
            'authors': ['Roderick Thorp'],
            'description': 'A novel that inspired the iconic action movie.',
            'imageLinks': {},
          },
        ];
        await _saveFallbackRecommendations(fallback);
        return fallback;
      }

      if (openAIApiKey.isEmpty) {
        print('OpenAI API key is missing. Please configure it in .env file.');
        final fallback = [
          {
            'title': 'The Bourne Identity',
            'authors': ['Robert Ludlum'],
            'description':
                'An action-packed thriller about a man with no memory.',
            'imageLinks': {},
          },
          {
            'title': 'Die Hard',
            'authors': ['Roderick Thorp'],
            'description': 'A novel that inspired the iconic action movie.',
            'imageLinks': {},
          },
        ];
        await _saveFallbackRecommendations(fallback);
        return fallback;
      }

      final genres = await _getUserGenres();
      final genrePrompt =
          genres.isNotEmpty
              ? 'Suggest 5 books that align with the following genres: ${genres.join(", ")}. Provide only the book title and author in a list format, e.g., "1. Title by Author".'
              : 'Suggest 5 popular books across various genres. Provide only the book title and author in a list format, e.g., "1. Title by Author".';

      print('Sending OpenAI request with prompt: $genrePrompt');
      final response = await http.post(
        Uri.parse(openAIUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openAIApiKey',
        },
        body: json.encode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'user', 'content': genrePrompt},
          ],
          'max_tokens': 200,
        }),
      );

      if (response.statusCode != 200) {
        print('OpenAI API error: ${response.statusCode} - ${response.body}');
        final fallback = [
          {
            'title': 'The Bourne Identity',
            'authors': ['Robert Ludlum'],
            'description':
                'An action-packed thriller about a man with no memory.',
            'imageLinks': {},
          },
          {
            'title': 'Die Hard',
            'authors': ['Roderick Thorp'],
            'description': 'A novel that inspired the iconic action movie.',
            'imageLinks': {},
          },
        ];
        await _saveFallbackRecommendations(fallback);
        return fallback;
      }

      final data = json.decode(response.body);
      final recommendationsText =
          data['choices'][0]['message']['content'] as String;
      print('OpenAI response: $recommendationsText');

      // Parse recommendations
      final recommendations =
          recommendationsText
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .map((line) {
                final parts = line.split(' by ');
                return {
                  'title': parts[0].replaceAll(RegExp(r'^\d+\.\s*'), '').trim(),
                  'author': parts.length > 1 ? parts[1].trim() : 'Unknown',
                };
              })
              .toList();

      // Fetch book details from Google Books API
      final detailedBooks = <Map<String, dynamic>>[];
      for (var rec in recommendations) {
        final query = '${rec['title']} ${rec['author']}';
        print('Fetching Google Books data for: $query');
        final booksResponse = await http.get(
          Uri.parse('$googleBooksUrl?q=$query'),
        );
        if (booksResponse.statusCode == 200) {
          final booksData = json.decode(booksResponse.body);
          if (booksData['items'] != null && booksData['items'].isNotEmpty) {
            detailedBooks.add(booksData['items'][0]['volumeInfo']);
          } else {
            print('No Google Books data found for: $query');
          }
        } else {
          print('Google Books API error: ${booksResponse.statusCode}');
        }
      }

      // Save recommendations to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user to save recommendations');
        return detailedBooks.isNotEmpty
            ? detailedBooks
            : [
              {
                'title': 'The Bourne Identity',
                'authors': ['Robert Ludlum'],
                'description':
                    'An action-packed thriller about a man with no memory.',
                'imageLinks': {},
              },
            ];
      }
      final batch = FirebaseFirestore.instance.batch();
      for (var book in detailedBooks) {
        final docRef =
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('recommended_books')
                .doc();
        batch.set(docRef, {
          'title': book['title'] ?? 'Unknown',
          'author': book['authors']?.join(', ') ?? 'Unknown',
          'description': book['description'] ?? '',
          'imageLinks': book['imageLinks'] ?? {},
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      print('Saved ${detailedBooks.length} recommendations to Firestore');

      return detailedBooks.isNotEmpty
          ? detailedBooks
          : [
            {
              'title': 'The Bourne Identity',
              'authors': ['Robert Ludlum'],
              'description':
                  'An action-packed thriller about a man with no memory.',
              'imageLinks': {},
            },
          ];
    } catch (e) {
      print('Error in getBookRecommendations: $e');
      final fallback = [
        {
          'title': 'The Bourne Identity',
          'authors': ['Robert Ludlum'],
          'description':
              'An action-packed thriller about a man with no memory.',
          'imageLinks': {},
        },
        {
          'title': 'Die Hard',
          'authors': ['Roderick Thorp'],
          'description': 'A novel that inspired the iconic action movie.',
          'imageLinks': {},
        },
      ];
      await _saveFallbackRecommendations(fallback);
      return fallback;
    }
  }

  // Helper to save fallback recommendations to Firestore
  static Future<void> _saveFallbackRecommendations(
    List<Map<String, dynamic>> fallback,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user to save fallback recommendations');
      return;
    }
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var book in fallback) {
        final docRef =
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('recommended_books')
                .doc();
        batch.set(docRef, {
          'title': book['title'] ?? 'Unknown',
          'author': book['authors']?.join(', ') ?? 'Unknown',
          'description': book['description'] ?? '',
          'imageLinks': book['imageLinks'] ?? {},
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      print('Saved ${fallback.length} fallback recommendations to Firestore');
    } catch (e) {
      print('Error saving fallback recommendations: $e');
    }
  }
}

**/

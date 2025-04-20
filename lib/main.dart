import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme_provider.dart';
import 'signin_screen.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'book_detail_screen.dart';
import 'reading_list_screen.dart';
import 'submit_review_screen.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart';
import 'settings_screen.dart';
import 'chat_screen.dart'; // Import the new chat screen
import 'package:ai_book/discussion_board_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  try {
    await dotenv.load(fileName: ".env"); // Load .env file
    print(
      'Loaded Google Books API Key: ${dotenv.env['GOOGLE_BOOKS_API_KEY']?.substring(0, 10)}...',
    ); // Debug log (remove in production)
  } catch (e) {
    print('Failed to load .env file: $e');
  }
  runApp(BookRecommendationApp());
}

class BookRecommendationApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'AI Book Recommendation',
            theme: themeProvider.getTheme(),
            home: AuthWrapper(),
            routes: {
              '/signin': (context) => SignInScreen(),
              '/signup': (context) => SignUpScreen(),
              '/home': (context) => HomeScreen(),
              '/search': (context) => SearchScreen(),
              '/book_detail': (context) => BookDetailScreen(),
              '/reading_list': (context) => ReadingListScreen(),
              '/submit_review': (context) => SubmitReviewScreen(),
              '/chat': (context) => ChatScreen(),
              '/user_profile': (context) => UserProfileScreen(),
              '/settings': (context) => SettingsScreen(),
              '/chat': (context) => ChatScreen(), // Add the new route
              '/discussion_board': (context) => DiscussionBoardScreen(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print('Auth error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.hasData) {
          print('Authenticated user: ${snapshot.data?.toString()}');
          return HomeScreen();
        }
        return SignInScreen();
      },
    );
  }
}

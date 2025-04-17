import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReadingListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('My Reading List')),
      body: StreamBuilder(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .collection('reading_list')
                .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          var books = snapshot.data!.docs;
          var wantToRead =
              books.where((doc) => doc['status'] == 'Want to Read').toList();
          var currentlyReading =
              books
                  .where((doc) => doc['status'] == 'Currently Reading')
                  .toList();
          var finished =
              books.where((doc) => doc['status'] == 'Finished').toList();

          return ListView(
            children: [
              _buildSection(context, 'Want to Read', wantToRead),
              _buildSection(context, 'Currently Reading', currentlyReading),
              _buildSection(context, 'Finished', finished),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<QueryDocumentSnapshot> books,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        books.isEmpty
            ? Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('No books in this category.'),
            )
            : Column(
              children:
                  books.map((book) {
                    return ListTile(
                      title: Text(book['title']),
                      subtitle: Text(book['author']),
                      trailing: DropdownButton<String>(
                        value: book['status'],
                        items:
                            ['Want to Read', 'Currently Reading', 'Finished']
                                .map(
                                  (status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status),
                                  ),
                                )
                                .toList(),
                        onChanged: (newStatus) async {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .collection('reading_list')
                              .doc(book.id)
                              .update({'status': newStatus});
                        },
                      ),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/book_detail',
                          arguments: book.data(),
                        );
                      },
                    );
                  }).toList(),
            ),
      ],
    );
  }
}

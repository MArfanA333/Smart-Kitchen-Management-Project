// expiry_notification_settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpiryNotificationSettingsPage extends StatefulWidget {
  const ExpiryNotificationSettingsPage({super.key});

  @override
  _ExpiryNotificationSettingsPageState createState() =>
      _ExpiryNotificationSettingsPageState();
}

class _ExpiryNotificationSettingsPageState
    extends State<ExpiryNotificationSettingsPage> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("User not logged in"));

    final expiryDatesStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preferences')
        .doc('expiry_dates')
        .collection('items')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expiry Notification Settings"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Search by Item Name",
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: expiryDatesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final name = doc['name'].toString().toLowerCase();
                  return name.contains(searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: ListTile(
                        title: Text(doc['name']),
                        subtitle: Text(
                            "Estimated Expiry: ${doc['estimated_expiry']}\nRemind: ${doc['remind_before']} day(s) before"),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editReminder(doc),
                        ),
                      ),
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

  void _editReminder(DocumentSnapshot doc) {
    final estimatedController =
        TextEditingController(text: doc['estimated_expiry'].toString());
    final remindController =
        TextEditingController(text: doc['remind_before'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit ${doc['name']} Settings"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: estimatedController,
              decoration:
                  const InputDecoration(labelText: "Estimated Expiry Days"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: remindController,
              decoration:
                  const InputDecoration(labelText: "Remind Before Days"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await doc.reference.update({
                'estimated_expiry': int.parse(estimatedController.text),
                'remind_before': int.parse(remindController.text),
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

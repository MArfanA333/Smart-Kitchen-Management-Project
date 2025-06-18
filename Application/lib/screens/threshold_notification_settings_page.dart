import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ThresholdNotificationSettingsPage extends StatefulWidget {
  const ThresholdNotificationSettingsPage({super.key});

  @override
  _ThresholdNotificationSettingsPageState createState() =>
      _ThresholdNotificationSettingsPageState();
}

class _ThresholdNotificationSettingsPageState
    extends State<ThresholdNotificationSettingsPage> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("User not logged in"));

    final thresholdStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preferences')
        .doc('threshold')
        .collection('items')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Threshold Notification Settings"),
        centerTitle: true,
        backgroundColor: Colors.deepOrangeAccent,
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
              stream: thresholdStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

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
                            "Minimum Quantity Threshold: ${doc['minimum']}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editThreshold(doc),
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

  void _editThreshold(DocumentSnapshot doc) {
    final minController =
        TextEditingController(text: doc['minimum'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Threshold for ${doc['name']}"),
        content: TextField(
          controller: minController,
          decoration: const InputDecoration(labelText: "Minimum Quantity"),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await doc.reference.update({
                'minimum': int.tryParse(minController.text) ?? 0,
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

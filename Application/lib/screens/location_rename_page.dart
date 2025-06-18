import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationRenamePage extends StatefulWidget {
  const LocationRenamePage({super.key});

  @override
  _LocationRenamePageState createState() => _LocationRenamePageState();
}

class _LocationRenamePageState extends State<LocationRenamePage> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    final locationsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('locations')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Storage Locations"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Search Locations",
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: locationsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final filtered = snapshot.data!.docs.where((doc) {
                  final name = doc['name'].toString().toLowerCase();
                  return name.contains(searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final currentCategory =
                        (doc['category'] as String?)?.toLowerCase() ??
                            "cabinet";

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: ListTile(
                        title: Text(doc['name']),
                        subtitle:
                            Text("Category: ${capitalize(currentCategory)}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editLocation(doc),
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

  void _editLocation(DocumentSnapshot doc) {
    final nameController = TextEditingController(text: doc['name']);
    String selectedCategory =
        (doc['category'] as String?)?.toLowerCase() ?? 'cabinet';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Location"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Location Name"),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: capitalize(selectedCategory),
              items: ['Freezer', 'Fridge', 'Cabinet']
                  .map((label) => DropdownMenuItem(
                        value: label,
                        child: Text(label),
                      ))
                  .toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  selectedCategory = newValue.toLowerCase();
                }
              },
              decoration: const InputDecoration(labelText: "Category"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await doc.reference.update({
                'name': nameController.text.trim(),
                'category': selectedCategory,
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  String capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1).toLowerCase();
  }
}

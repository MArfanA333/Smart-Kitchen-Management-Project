import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'saved_collection_recipes_page.dart';

class SavedRecipesPage extends StatefulWidget {
  const SavedRecipesPage({Key? key}) : super(key: key);

  @override
  State<SavedRecipesPage> createState() => _SavedRecipesPageState();
}

class _SavedRecipesPageState extends State<SavedRecipesPage> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  Color _pickedColor = Colors.blueAccent;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view your collections.")),
      );
    }

    final collectionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('recipes')
        .doc('saved')
        .collection('collection');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Recipe Collections'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCollectionDialog(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: collectionRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];

          // Sort alphabetically by 'name'
          docs.sort((a, b) {
            final aName = (a['name'] as String).toLowerCase();
            final bName = (b['name'] as String).toLowerCase();
            return aName.compareTo(bName);
          });

          if (docs.isEmpty) {
            return const Center(
                child: Text('No collections yet.\nTap + to create one.',
                    textAlign: TextAlign.center));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final collectionId = doc.id;
              final name = data['name'] as String? ?? 'Unnamed';
              final colorVal = data['color'] as int? ?? Colors.grey.value;
              final color = Color(colorVal);

              return GestureDetector(
                onLongPress: () => _showCollectionDialog(
                  collectionId: collectionId,
                  currentName: name,
                  currentColor: colorVal,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.2), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: ListTile(
                    title: Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color.darken(0.2),
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SavedCollectionRecipesPage(
                            userId: user!.uid,
                            collectionId: collectionId,
                            collectionName: name,
                            collectionColor: color,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Shared dialog for both creating & renaming a collection.
  Future<void> _showCollectionDialog({
    String? collectionId,
    String? currentName,
    int? currentColor,
  }) async {
    _nameController.text = currentName ?? '';
    _pickedColor =
        currentColor != null ? Color(currentColor) : Colors.blueAccent;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              collectionId == null ? 'New Collection' : 'Rename Collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Collection Name'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Colors.primaries.take(12).map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => _pickedColor = color);
                      // rebuild dialog to show selection
                      Navigator.pop(context);
                      _showCollectionDialog(
                        collectionId: collectionId,
                        currentName: _nameController.text,
                        currentColor: _pickedColor.value,
                      );
                    },
                    child: CircleAvatar(
                      backgroundColor: color,
                      child: _pickedColor.value == color.value
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;

                final ref = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('recipes')
                    .doc('saved')
                    .collection('collection');

                if (collectionId == null) {
                  // Create new
                  await ref.add({
                    'name': name,
                    'color': _pickedColor.value,
                    'recipes': <String>[],
                  });
                } else {
                  // Rename / recolor existing
                  await ref.doc(collectionId).update({
                    'name': name,
                    'color': _pickedColor.value,
                  });
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

/// Extension to darken a color slightly.
extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    final f = 1 - amount;
    return Color.fromARGB(
      alpha,
      (red * f).round(),
      (green * f).round(),
      (blue * f).round(),
    );
  }
}

// lib/saved_collection_recipes_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recipe_detail_page.dart';

class SavedCollectionRecipesPage extends StatefulWidget {
  final String userId;
  final String collectionId;
  final String collectionName;
  final Color collectionColor;

  const SavedCollectionRecipesPage({
    Key? key,
    required this.userId,
    required this.collectionId,
    required this.collectionName,
    required this.collectionColor,
  }) : super(key: key);

  @override
  _SavedCollectionRecipesPageState createState() =>
      _SavedCollectionRecipesPageState();
}

class _SavedCollectionRecipesPageState
    extends State<SavedCollectionRecipesPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// Reference to the collection document itself
  DocumentReference get _collectionDoc => FirebaseFirestore.instance
      .collection('users')
      .doc(widget.userId)
      .collection('recipes')
      .doc('saved')
      .collection('collection')
      .doc(widget.collectionId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collectionName),
        backgroundColor: widget.collectionColor,
      ),
      body: Column(
        children: [
          // ─── Search Bar ─────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search recipes…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (val) => setState(() {
                _searchQuery = val.trim().toLowerCase();
              }),
            ),
          ),

          // ─── Recipes List ───────────────────────
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _collectionDoc.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || !snap.data!.exists) {
                  return const Center(
                    child: Text('Collection not found.'),
                  );
                }

                final data = snap.data!.data()! as Map<String, dynamic>;
                // Pull the array of recipeIds
                final recipeIds =
                    List<String>.from(data['recipes'] ?? <String>[]);

                if (recipeIds.isEmpty) {
                  return const Center(
                    child: Text('No recipes in this collection.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: recipeIds.length,
                  itemBuilder: (context, i) {
                    final recipeId = recipeIds[i];

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('recipes')
                          .doc(recipeId)
                          .get(),
                      builder: (context, recipeSnap) {
                        if (recipeSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(title: Text('Loading…'));
                        }
                        if (!recipeSnap.hasData || !recipeSnap.data!.exists) {
                          // Skip nonexistent recipes
                          return const SizedBox.shrink();
                        }

                        final rd =
                            recipeSnap.data!.data()! as Map<String, dynamic>;
                        final name = (rd['Name'] ?? 'Unnamed').toString();
                        final nameLower = name.toLowerCase();

                        // Filter by search query
                        if (_searchQuery.isNotEmpty &&
                            !nameLower.contains(_searchQuery)) {
                          return const SizedBox.shrink();
                        }

                        final images = rd['Images'] as List? ?? [];
                        final imageUrl =
                            images.isNotEmpty ? images.first as String : null;

                        // May be double, so coerce:
                        final rating =
                            (rd['AggregatedRating'] ?? 0.0).toDouble();
                        final reviewsCount =
                            ((rd['ReviewCount'] ?? 0) as num).toInt();

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    Icons.fastfood,
                                    size: 60,
                                    color: widget.collectionColor,
                                  ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(rating.toStringAsFixed(1)),
                                const SizedBox(width: 8),
                                Text('($reviewsCount reviews)',
                                    style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                // Remove recipeId from the array
                                await _collectionDoc.update({
                                  'recipes': FieldValue.arrayRemove([recipeId])
                                });
                              },
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RecipeDetailPage(recipeId: recipeId),
                                ),
                              );
                            },
                          ),
                        );
                      },
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

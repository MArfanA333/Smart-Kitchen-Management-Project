import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'recipe_detail_page.dart';

class ViewedRecipesPage extends StatefulWidget {
  const ViewedRecipesPage({Key? key}) : super(key: key);

  @override
  State<ViewedRecipesPage> createState() => _ViewedRecipesPageState();
}

class _ViewedRecipesPageState extends State<ViewedRecipesPage> {
  List<DocumentSnapshot> recipes = [];
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _markAsViewedAndFetch();
  }

  /// When the page loads, add this recipeId to the "viewed" collection,
  /// then fetch all viewed recipes.
  Future<void> _markAsViewedAndFetch() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    // Fetch and store viewed items document references
    final viewedItemsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('recipes')
        .doc('viewed')
        .collection('items');

    // We don't have a single recipeId here, so we skip marking—it
    // assumed you call this on each detail page. We just fetch:
    await _fetchViewedRecipes();
  }

  Future<void> _fetchViewedRecipes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    final viewedSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('recipes')
        .doc('viewed')
        .collection('items')
        .get();

    final recipeIds = viewedSnapshot.docs.map((d) => d.id).toList();
    if (recipeIds.isEmpty) {
      setState(() {
        recipes = [];
        isLoading = false;
      });
      return;
    }

    final snapped = await FirebaseFirestore.instance
        .collection('recipes')
        .where('Id', whereIn: recipeIds)
        .get();

    setState(() {
      recipes = snapped.docs;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = recipes.where((doc) {
      final name = (doc['Name'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Viewed Recipes'),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // SEARCH BAR
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search Recipes',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) =>
                        setState(() => searchQuery = val.trim().toLowerCase()),
                  ),
                ),

                // RECIPE CARDS
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No recipes found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final doc = filtered[idx];
                            final data = doc.data() as Map<String, dynamic>;
                            final recipeId = doc.id;
                            final images = data['Images'] as List?;
                            final imageUrl =
                                (images != null && images.isNotEmpty)
                                    ? images.first as String
                                    : null;
                            final rating =
                                (data['AggregatedRating'] ?? 0.0) as double;
// new (handles both int and double safely):
                            final reviews = (data['ReviewCount'] ?? 0) is num
                                ? (data['ReviewCount'] as num).toInt()
                                : 0;
                            final keywords = List<String>.from(
                                data['Keywords'] ?? <String>[]);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          RecipeDetailPage(recipeId: recipeId),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (imageUrl != null)
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(16)),
                                        child: Image.network(
                                          imageUrl,
                                          width: double.infinity,
                                          height: 180,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['Name'] ?? 'Unnamed Recipe',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.star,
                                                  color: Colors.amber,
                                                  size: 18),
                                              const SizedBox(width: 4),
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '($reviews reviews)',
                                                style: const TextStyle(
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          keywords.isNotEmpty
                                              ? Wrap(
                                                  spacing: 8,
                                                  children: keywords
                                                      .map((tag) => Chip(
                                                            label: Text(tag),
                                                            backgroundColor:
                                                                Colors.blue
                                                                    .shade50,
                                                          ))
                                                      .toList(),
                                                )
                                              : const Text(
                                                  'No tags available.',
                                                  style: TextStyle(
                                                      color: Colors.grey),
                                                ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

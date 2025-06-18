import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'recipe_detail_page.dart';

class ExploreRecipesPage extends StatefulWidget {
  const ExploreRecipesPage({super.key});

  @override
  State<ExploreRecipesPage> createState() => _ExploreRecipesPageState();
}

class _ExploreRecipesPageState extends State<ExploreRecipesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _recipes = [];
  String userId = FirebaseAuth.instance.currentUser!.uid;
  bool _isSearching = false;
  bool _isFallback = false;

  @override
  void initState() {
    super.initState();
    _fetchRecommendedRecipes();
  }

  Future<List<String>> _getUserInventoryIngredients() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .get();

    return snapshot.docs
        .map((doc) => (doc.data()['name'] ?? '').toString().toLowerCase())
        .toList();
  }

  Future<void> _fetchRecommendedRecipes() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recipes')
          .doc('recommended')
          .collection('items')
          .get();

      if (snapshot.docs.isEmpty) {
        _fetchTopRatedRecipes();
        return;
      }

      final List<DocumentSnapshot> recipes = [];
      for (var doc in snapshot.docs) {
        final recipeDoc = await FirebaseFirestore.instance
            .collection('recipes')
            .doc(doc.id)
            .get();
        if (recipeDoc.exists) recipes.add(recipeDoc);
      }

      if (recipes.isEmpty) {
        _fetchTopRatedRecipes();
      } else {
        setState(() {
          _recipes = recipes;
          _isSearching = false;
          _isFallback = false;
        });
      }
    } catch (e) {
      _fetchTopRatedRecipes();
    }
  }

  Future<void> _fetchTopRatedRecipes() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('recipes')
        .orderBy('AggregatedRating', descending: true)
        .limit(15)
        .get();

    setState(() {
      _recipes = snapshot.docs;
      _isSearching = false;
      _isFallback = true;
    });
  }

  Future<void> _searchRecipes(String query) async {
    if (query.trim().isEmpty) {
      _fetchRecommendedRecipes();
      return;
    }

    final q = query.toLowerCase();

    final allRecipes =
        await FirebaseFirestore.instance.collection('recipes').get();

    final results = allRecipes.docs.where((doc) {
      final data = doc.data();
      final name = (data['Name'] ?? '').toString().toLowerCase();
      final keywords =
          List<String>.from(data['Keywords'] ?? []).map((k) => k.toLowerCase());

      return name.contains(q) || keywords.any((k) => k.contains(q));
    }).toList();

    setState(() {
      _recipes = results;
      _isSearching = true;
    });
  }

  Future<int> _countMissingIngredients(List<dynamic> ingredients) async {
    final inventory = await _getUserInventoryIngredients();
    final missing = ingredients
        .whereType<String>()
        .where((ing) => !inventory.contains(ing.toLowerCase()))
        .length;
    return missing;
  }

  Future<void> _logInteraction(String recipeId) async {
    final log = {
      'date': DateTime.now(),
      'message': 'User opened recipe: $recipeId',
    };
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('logs')
        .doc('interaction')
        .collection('itemList')
        .add(log);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Recipes'),
        backgroundColor: Colors.orange,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _searchRecipes,
              decoration: InputDecoration(
                hintText: 'Search recipes by name or keyword',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _recipes.isEmpty
          ? Center(
              child: Text(
                _isSearching
                    ? 'No recipes match your search.'
                    : 'No recipes found.',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _recipes.length,
              itemBuilder: (context, index) {
                final doc = _recipes[index];
                final data = doc.data() as Map<String, dynamic>;
                final recipeId = doc.id;
                final imageList = data['Images'] as List?;
                final imageUrl = (imageList != null && imageList.isNotEmpty)
                    ? imageList.first
                    : null;

                final keywords =
                    List<String>.from(data['Keywords'] ?? <String>[]);

                return FutureBuilder<int>(
                  future: _countMissingIngredients(
                      data['RecipeIngredientParts'] ?? []),
                  builder: (context, snapshot) {
                    final missingCount = snapshot.data ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: InkWell(
                        onTap: () async {
                          await _logInteraction(recipeId);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RecipeDetailPage(recipeId: recipeId),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageUrl != null)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16)),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 180,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                          color: Colors.amber, size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        (data['AggregatedRating'] ?? 0)
                                            .toStringAsFixed(1),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${data['ReviewCount'] ?? 0} reviews)',
                                        style:
                                            const TextStyle(color: Colors.grey),
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
                                                        Colors.blue.shade50,
                                                  ))
                                              .toList(),
                                        )
                                      : const Text(
                                          'No tags available.',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                  const SizedBox(height: 8),
                                  Text(
                                    missingCount == 0
                                        ? 'All ingredients available'
                                        : '$missingCount ingredient(s) missing',
                                    style: TextStyle(
                                      color: missingCount == 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

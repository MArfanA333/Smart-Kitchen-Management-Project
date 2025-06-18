import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'recipe_detail_page.dart';

class ReviewedRecipe {
  final DocumentSnapshot recipe;
  final DocumentSnapshot? userReview;

  ReviewedRecipe({required this.recipe, this.userReview});
}

class ReviewedRecipesPage extends StatefulWidget {
  const ReviewedRecipesPage({super.key});

  @override
  State<ReviewedRecipesPage> createState() => _ReviewedRecipesPageState();
}

class _ReviewedRecipesPageState extends State<ReviewedRecipesPage> {
  List<ReviewedRecipe> _allRecipes = [];
  List<ReviewedRecipe> _filteredRecipes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchReviewedRecipes();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _fetchReviewedRecipes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reviewedSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('recipes')
        .doc('reviewed')
        .collection('items')
        .get();

    List<String> recipeIds =
        reviewedSnapshot.docs.map((doc) => doc.id).toList();

    if (recipeIds.isEmpty) {
      setState(() {
        _allRecipes = [];
        _filteredRecipes = [];
        _isLoading = false;
      });
      return;
    }

    final List<ReviewedRecipe> fetchedRecipes = [];

    for (String recipeId in recipeIds) {
      final recipeDoc = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .get();

      if (recipeDoc.exists) {
        final reviewDoc = await FirebaseFirestore.instance
            .collection('recipes')
            .doc(recipeId)
            .collection('reviews')
            .doc(user.uid)
            .get();

        fetchedRecipes.add(ReviewedRecipe(
          recipe: recipeDoc,
          userReview: reviewDoc.exists ? reviewDoc : null,
        ));
      }
    }

    setState(() {
      _allRecipes = fetchedRecipes;
      _filteredRecipes = fetchedRecipes;
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredRecipes = _allRecipes.where((reviewedRecipe) {
        final recipeData = reviewedRecipe.recipe.data() as Map<String, dynamic>;
        final recipeName = recipeData['Name']?.toString().toLowerCase() ?? '';
        return recipeName.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviewed Recipes'),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search reviewed recipes...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredRecipes.isEmpty
                      ? const Center(child: Text('No recipes found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredRecipes.length,
                          itemBuilder: (context, index) {
                            final recipeData = _filteredRecipes[index]
                                .recipe
                                .data() as Map<String, dynamic>;
                            final userReview = _filteredRecipes[index]
                                .userReview
                                ?.data() as Map<String, dynamic>?;

                            final recipeId = _filteredRecipes[index].recipe.id;
                            final imageList = recipeData['Images'] as List?;
                            final imageUrl =
                                (imageList != null && imageList.isNotEmpty)
                                    ? imageList.first
                                    : null;

                            final keywords = List<String>.from(
                                recipeData['Keywords'] ?? <String>[]);
                            final userRating = userReview?['Rating'];
                            final userReviewText = userReview?['Review'];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              child: InkWell(
                                onTap: () {
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
                                        borderRadius:
                                            const BorderRadius.vertical(
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            recipeData['Name'] ??
                                                'Unnamed Recipe',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.star,
                                                  color: Colors.amber,
                                                  size: 18),
                                              const SizedBox(width: 4),
                                              Text(
                                                (recipeData['AggregatedRating'] ??
                                                        0)
                                                    .toStringAsFixed(1),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '(${recipeData['ReviewCount'] ?? 0} reviews)',
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
                                          const SizedBox(height: 12),
                                          if (userRating != null) ...[
                                            Text(
                                              'Your Rating: ${userRating.toString()} ⭐',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                          if (userReviewText != null &&
                                              userReviewText.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              '"$userReviewText"',
                                              style: const TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
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

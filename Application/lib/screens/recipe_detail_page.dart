// lib/recipe_detail_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RecipeDetailPage extends StatefulWidget {
  final String recipeId;
  const RecipeDetailPage({Key? key, required this.recipeId}) : super(key: key);

  @override
  _RecipeDetailPageState createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  // REVIEW CONTROLS
  final TextEditingController _reviewController = TextEditingController();
  int _rating = 1;
  bool _isSubmittingReview = false;
  bool _isUserReviewed = false;

  // COLLECTION POPUP DATA
  List<Map<String, dynamic>> _userCollections = [];
  bool _collectionsLoading = true;

  // EXISTING REVIEW DOC ID (== user.uid)
  String? _existingReviewId;

  @override
  void initState() {
    super.initState();
    _markRecipeAsViewed();
    _checkForExistingReview();
    _fetchUserCollections();
  }

  /// 1) Mark as viewed under users/{uid}/recipes/viewed/items/{recipeId}
  Future<void> _markRecipeAsViewed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('recipes')
        .doc('viewed')
        .collection('items')
        .doc(widget.recipeId)
        .set({
      'recipeId': widget.recipeId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// 2) Check if current user has already reviewed this recipe
  Future<void> _checkForExistingReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .collection('reviews')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _isUserReviewed = true;
        _existingReviewId = user.uid;
        _rating = (data['Rating'] as num).round().clamp(1, 5);
        _reviewController.text = data['Review'] as String? ?? '';
      });
    }
  }

  /// 3) Load all collections (id + name)
  Future<void> _fetchUserCollections() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('recipes')
        .doc('saved')
        .collection('collection')
        .get();

    setState(() {
      _userCollections = snap.docs.map((d) {
        final data = d.data();
        return <String, dynamic>{
          'id': d.id,
          'name': data['name'] as String? ?? 'Unnamed',
        };
      }).toList();
      _collectionsLoading = false;
    });
  }

  /// 4) Show pop‑up to pick a collection and save
  Future<void> _showSaveToCollectionDialog() async {
    if (_collectionsLoading) return;
    if (_userCollections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No collections available.')),
      );
      return;
    }

    String selectedId = _userCollections.first['id']! as String;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Save to Collection'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return DropdownButtonFormField<String>(
                value: selectedId,
                decoration: const InputDecoration(
                  labelText: 'Select Collection',
                  border: OutlineInputBorder(),
                ),
                items: _userCollections.map((col) {
                  return DropdownMenuItem<String>(
                    value: col['id'] as String,
                    child: Text(col['name'] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setStateDialog(() => selectedId = val);
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final colRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('recipes')
                      .doc('saved')
                      .collection('collection')
                      .doc(selectedId);

                  // Append recipeId into the 'recipes' array field
                  await colRef.update({
                    'recipes': FieldValue.arrayUnion([widget.recipeId])
                  });

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Recipe saved to collection.')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// 5) Submit or update review and recalc aggregated rating + count
  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final displayName = user.displayName ?? 'Anonymous';

    setState(() => _isSubmittingReview = true);

    try {
      final reviewRef = FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .collection('reviews')
          .doc(uid);

      final reviewData = {
        'AuthorName': displayName,
        'DateModified': FieldValue.serverTimestamp(),
        'DateSubmitted': FieldValue.serverTimestamp(),
        'Rating': _rating.toDouble(),
        'Review': _reviewController.text.trim(),
      };

      if (_isUserReviewed) {
        await reviewRef.update(reviewData);
      } else {
        await reviewRef.set(reviewData);
        _isUserReviewed = true;
      }

      // Recalculate average & count
      await _updateAggregatedRatingAndCount();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit review.')),
      );
    } finally {
      setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _updateAggregatedRatingAndCount() async {
    final col = FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .collection('reviews');

    final snap = await col.get();
    final count = snap.docs.length;
    double total = 0;
    for (var doc in snap.docs) {
      total += (doc.data()['Rating'] as num).toDouble();
    }
    final avg = count > 0 ? total / count : 0.0;

    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .update({
      'AggregatedRating': avg,
      'ReviewCount': count,
    });
  }

  /// 6) Add recipe to meal planner
  Future<void> _addToMealPlanner() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final mealPlannerRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('meal_planner')
        .doc('weekly_meals') // or specific day document
        .update({
      'meal_ids': FieldValue.arrayUnion([widget.recipeId]),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recipe added to Meal Planner')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Details'),
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('recipes')
            .doc(widget.recipeId)
            .get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Recipe not found.'));
          }
          final data = snap.data!.data()! as Map<String, dynamic>;

          // Ingredients & quantities
          final parts =
              List<String>.from(data['RecipeIngredientParts'] ?? <String>[]);
          final quants = (data['RecipeIngredientQuantities'] as List?)
                  ?.map((q) => '${q.toString()}g')
                  .toList() ??
              [];

          // Instructions split on '.' into steps
          final instr =
              (data['RecipeInstructions'] ?? '').toString().split('.');

          final tags = List<String>.from(data['Keywords'] ?? <String>[]);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // IMAGE
                if (data['Images'] is List &&
                    (data['Images'] as List).isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      (data['Images'] as List).first,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 180,
                    ),
                  ),
                const SizedBox(height: 16),

                // NAME
                Text(
                  data['Name'] ?? 'Unnamed Recipe',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // RATING + COUNT
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      (data['AggregatedRating'] as num? ?? 0.0)
                          .toDouble()
                          .toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${data['ReviewCount'] ?? 0} reviews)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // TAGS
                const Text('Tags:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: tags
                        .map((t) => Chip(
                              label: Text(t),
                              backgroundColor: Colors.blue.shade50,
                            ))
                        .toList(),
                  )
                else
                  const Text('No tags available.',
                      style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),

                // INGREDIENTS
                const Text('Ingredients:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: parts.length,
                  itemBuilder: (ctx, i) {
                    return ListTile(
                      dense: true,
                      title: Text(parts[i]),
                      trailing: Text(i < quants.length ? quants[i] : ''),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // INSTRUCTIONS
                const Text('Instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: instr.length,
                  itemBuilder: (ctx, i) {
                    final step = instr[i].trim();
                    if (step.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${i + 1}. $step.'),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // REVIEW SECTION
                const Text('Add Your Review:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButton<int>(
                  value: _rating,
                  items: List.generate(5, (i) {
                    final val = i + 1;
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text('$val Star${val > 1 ? 's' : ''}'),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) setState(() => _rating = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reviewController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Write your review here...',
                  ),
                ),
                const SizedBox(height: 16),
                _isSubmittingReview
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submitReview,
                        child: Text(
                            _isUserReviewed ? 'Edit Review' : 'Submit Review'),
                      ),
                const SizedBox(height: 24),

                // SAVE TO COLLECTION POPUP
                ElevatedButton.icon(
                  onPressed: _showSaveToCollectionDialog,
                  icon: const Icon(Icons.bookmark),
                  label: const Text('Save to Collection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

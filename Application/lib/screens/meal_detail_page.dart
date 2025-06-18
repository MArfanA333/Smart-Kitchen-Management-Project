import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MealDetailPage extends StatefulWidget {
  final String userId;
  final String dayName;
  final String mealId;
  final Map<String, dynamic> mealData;

  const MealDetailPage({
    Key? key,
    required this.userId,
    required this.dayName,
    required this.mealId,
    required this.mealData,
  }) : super(key: key);

  @override
  State<MealDetailPage> createState() => _MealDetailPageState();
}

class _MealDetailPageState extends State<MealDetailPage> {
  late DocumentReference mealDoc;
  List<DocumentSnapshot> recipeDocs = [];
  Map<String, double> ingredientTotals = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    mealDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('meals')
        .doc(widget.dayName)
        .collection('mealList')
        .doc(widget.mealId);
    _fetchRecipes();
  }

  Future<void> _fetchRecipes() async {
    setState(() => isLoading = true);

    final mealSnapshot = await mealDoc.get();
    final mealData = mealSnapshot.data() as Map<String, dynamic>?;

    final List<dynamic> recipeEntries = mealData?['recipes'] ?? [];

    recipeDocs.clear();

    final recipeFutures = recipeEntries.map((entry) {
      final recipeId = entry is String ? entry : entry['id'];
      return FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .get();
    });

    final fetchedDocs = await Future.wait(recipeFutures);
    recipeDocs = fetchedDocs;

    final Map<String, double> ingredientSums = {};

    for (var doc in recipeDocs) {
      final data = doc.data() as Map<String, dynamic>?;

      if (data != null &&
          data.containsKey('RecipeIngredientParts') &&
          data.containsKey('RecipeIngredientQuantities')) {
        final List<dynamic> parts = data['RecipeIngredientParts'];
        final List<dynamic> quantities = data['RecipeIngredientQuantities'];

        for (int i = 0; i < parts.length; i++) {
          final name = parts[i].toString();
          final quantity = (i < quantities.length && quantities[i] is num)
              ? (quantities[i] as num).toDouble()
              : 0.0;

          ingredientSums[name] = (ingredientSums[name] ?? 0) + quantity;
        }
      }
    }

    setState(() {
      ingredientTotals = ingredientSums;
      isLoading = false;
    });
  }

  Future<void> _addRecipe() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    List<DocumentSnapshot> collectionDocs = [];
    List<String> collectionNames = [];

    String? selectedCollectionId;
    String? selectedCollectionName;
    String? selectedRecipeId;

    List<Map<String, String>> recipeOptions = [];

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> fetchCollections() async {
              final snapshot = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('recipes')
                  .doc('saved')
                  .collection('collection')
                  .get();

              collectionDocs = snapshot.docs;
              collectionNames = collectionDocs
                  .map((doc) => doc.data().toString().contains('name')
                      ? doc['name'] as String
                      : doc.id)
                  .toList();

              setState(() {});
            }

            Future<void> fetchRecipesFromCollection(String collectionId) async {
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('recipes')
                  .doc('saved')
                  .collection('collection')
                  .doc(collectionId)
                  .get();

              final List<dynamic> recipeIds = doc.data()?['recipes'] ?? [];
              List<Map<String, String>> loadedRecipes = [];

              for (String recipeId in recipeIds.cast<String>()) {
                final recipeDoc = await FirebaseFirestore.instance
                    .collection('recipes')
                    .doc(recipeId)
                    .get();

                if (recipeDoc.exists) {
                  final recipeName = recipeDoc.data()?['Name'] ?? 'Unnamed';
                  loadedRecipes.add({'id': recipeId, 'name': recipeName});
                }
              }

              setState(() {
                recipeOptions = loadedRecipes;
                selectedRecipeId = null;
              });
            }

            if (collectionNames.isEmpty) {
              fetchCollections();
            }

            return AlertDialog(
              title: const Text('Add Recipe to Meal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Select a collection'),
                    value: selectedCollectionName,
                    onChanged: (value) {
                      if (value != null) {
                        final index = collectionNames.indexOf(value);
                        final docId = collectionDocs[index].id;

                        setState(() {
                          selectedCollectionName = value;
                          selectedCollectionId = docId;
                          recipeOptions = [];
                          selectedRecipeId = null;
                        });

                        fetchRecipesFromCollection(docId);
                      }
                    },
                    items: collectionNames
                        .map((name) => DropdownMenuItem<String>(
                              value: name,
                              child: Text(name),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  if (recipeOptions.isNotEmpty)
                    DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Select a recipe'),
                      value: selectedRecipeId,
                      onChanged: (value) {
                        setState(() {
                          selectedRecipeId = value;
                        });
                      },
                      items: recipeOptions
                          .map((recipe) => DropdownMenuItem<String>(
                                value: recipe['id'],
                                child: Text(recipe['name'] ?? 'Unnamed'),
                              ))
                          .toList(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedRecipeId == null
                      ? null
                      : () async {
                          final now = DateTime.now();

                          await mealDoc.update({
                            'recipes': FieldValue.arrayUnion([
                              {
                                'id': selectedRecipeId,
                                'addedAt': now,
                              }
                            ])
                          });

                          final selectedRecipeName = recipeOptions.firstWhere(
                              (r) => r['id'] == selectedRecipeId)['name'];

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .collection('logs')
                              .doc('itemList')
                              .collection('interaction')
                              .add({
                            'date': now,
                            'message':
                                'Recipe "$selectedRecipeName" was added to ${widget.dayName}\'s "${widget.mealData['name']}" meal.',
                          });

                          Navigator.pop(context);
                          _fetchRecipes();
                        },
                  child: const Text('Add Recipe'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeRecipe(String recipeId) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final now = DateTime.now();

    final removedDoc = recipeDocs.firstWhere((doc) => doc.id == recipeId);
    final removedData = removedDoc.data() as Map<String, dynamic>;
    final removedName = removedData['Name'] ?? 'Unnamed';

    await mealDoc.update({
      'recipes': FieldValue.arrayRemove([recipeId])
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('logs')
        .doc('itemList')
        .collection('interaction')
        .add({
      'date': now,
      'message':
          'Recipe "$removedName" was removed from ${widget.dayName}\'s "${widget.mealData['name']}" meal.',
    });

    await _fetchRecipes();
  }

  Map<String, double> _calculateTotals() {
    final totals = <String, double>{
      'Calories': 0,
      'ProteinContent': 0,
      'FatContent': 0,
      'CarbohydrateContent': 0,
      'FiberContent': 0,
      'SugarContent': 0,
      'CholesterolContent': 0,
      'SodiumContent': 0,
    };

    for (final doc in recipeDocs) {
      final data = doc.data() as Map<String, dynamic>;

      for (final key in totals.keys) {
        final value = data[key];
        if (value != null && value is num) {
          totals[key] = totals[key]! + value.toDouble();
        }
      }
    }

    return totals;
  }

  Widget _buildNutritionCard(Map<String, double> nutrition) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: nutrition.entries
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${e.key}: ${e.value.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 15),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildIngredientsList(Map<String, double> ingredients) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ingredients.entries
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${e.key}: ${e.value.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 15),
                  ),
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mealName = widget.mealData['name'] ?? 'Unnamed Meal';

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.dayName} — $mealName'),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Nutrition',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  _buildNutritionCard(_calculateTotals()),
                  const SizedBox(height: 16),
                  const Text(
                    'Total Ingredients Needed',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  _buildIngredientsList(ingredientTotals),
                  const SizedBox(height: 16),
                  const Text(
                    'Recipes in this meal',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (recipeDocs.isEmpty)
                    const Text('No recipes added yet.')
                  else
                    Column(
                      children: recipeDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final recipeName = data['Name'] ?? 'Unnamed';
                        final recipeId = doc.id;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            title: Text(recipeName),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeRecipe(recipeId),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRecipe,
        child: const Icon(Icons.add),
      ),
    );
  }
}

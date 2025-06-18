import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'edit_recipe_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreatedRecipesPage extends StatefulWidget {
  const CreatedRecipesPage({super.key});

  @override
  State<CreatedRecipesPage> createState() => _CreatedRecipesPageState();
}

class _CreatedRecipesPageState extends State<CreatedRecipesPage> {
  List<DocumentSnapshot> recipes = [];
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRecipes();
  }

  Future<void> fetchRecipes() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final createdSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .doc('created')
        .collection('items')
        .get();

    final recipeIds = createdSnapshot.docs.map((doc) => doc.id).toList();

    if (recipeIds.isNotEmpty) {
      final List<DocumentSnapshot> allRecipes = [];
      const int batchSize = 10;

      for (int i = 0; i < recipeIds.length; i += batchSize) {
        final batchIds = recipeIds.sublist(
          i,
          i + batchSize > recipeIds.length ? recipeIds.length : i + batchSize,
        );

        final result = await FirebaseFirestore.instance
            .collection('recipes')
            .where('Id', whereIn: batchIds)
            .get();

        allRecipes.addAll(result.docs);
      }

      setState(() {
        recipes = allRecipes;
        isLoading = false;
      });
    } else {
      setState(() {
        recipes = [];
        isLoading = false;
      });
    }
  }

  Future<void> deleteRecipe(String recipeId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipeId)
        .delete();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .doc('created')
        .collection('items')
        .doc(recipeId)
        .delete();

    fetchRecipes();
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecipes = recipes.where((doc) {
      final name = (doc['Name'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Created Recipes'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search Recipes',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: filteredRecipes.isEmpty
                      ? const Center(child: Text('No recipes found.'))
                      : ListView.builder(
                          itemCount: filteredRecipes.length,
                          itemBuilder: (context, index) {
                            final recipe = filteredRecipes[index];
                            final recipeId = recipe.id;
                            final recipeData =
                                recipe.data() as Map<String, dynamic>;

                            return ListTile(
                              title: Text(recipeData['Name']),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EditRecipePage(
                                            recipeId: recipeId,
                                            recipeData: recipeData,
                                          ),
                                        ),
                                      ).then((_) => fetchRecipes());
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => deleteRecipe(recipeId),
                                  ),
                                ],
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

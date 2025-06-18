import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddRecipePage extends StatefulWidget {
  const AddRecipePage({super.key});

  @override
  State<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  final TextEditingController recipeNameController = TextEditingController();
  final TextEditingController instructionsController = TextEditingController();
  final TextEditingController expiryController = TextEditingController();
  final TextEditingController servingsController = TextEditingController();
  final TextEditingController yieldController = TextEditingController();
  final TextEditingController prepTimeController = TextEditingController();
  final TextEditingController cookTimeController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController keywordsController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController weightController = TextEditingController();

  List<DocumentSnapshot> searchResults = [];
  bool isLoading = false;
  List<Map<String, dynamic>> addedIngredients = [];

  double totalCalories = 0;
  double totalCarbs = 0;
  double totalProtein = 0;
  double totalFat = 0;
  double totalSugar = 0;
  double totalFiber = 0;
  double totalSaturatedFat = 0;
  double totalCholesterol = 0;
  double totalSodium = 0;

  void _searchIngredients(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      isLoading = true;
      searchResults = [];
    });

    final result = await FirebaseFirestore.instance
        .collection('ingredients_list')
        .where('name_lower', isGreaterThanOrEqualTo: query.toLowerCase())
        .where('name_lower',
            isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
        .limit(20)
        .get();

    setState(() {
      searchResults = result.docs;
      isLoading = false;
    });
  }

  void _addIngredient(DocumentSnapshot doc, double weight) {
    final data = doc.data() as Map<String, dynamic>;
    final ingredient = {
      'id': doc.id,
      'name': data['name'],
      'weight': weight,
      'nutrition': {
        'calories': data['calories'],
        'carbohydrate': data['carbohydrate'],
        'fat': data['fat'],
        'fiber': data['fiber'],
        'protein': data['protein'],
        'saturatedfat': data['saturatedfat'],
        'sugar': data['sugar'],
        'cholesterol': data['cholesterol'],
        'sodium': data['sodium'],
      }
    };

    addedIngredients.add(ingredient);
    _calculateNutrition();

    setState(() {
      searchController.clear();
      weightController.clear();
      searchResults.clear();
    });
  }

  void _calculateNutrition() {
    totalCalories = 0;
    totalCarbs = 0;
    totalProtein = 0;
    totalFat = 0;
    totalSugar = 0;
    totalFiber = 0;
    totalSaturatedFat = 0;
    totalCholesterol = 0;
    totalSodium = 0;

    for (var ingredient in addedIngredients) {
      double factor = ingredient['weight'] / 100.0;
      var nutrition = ingredient['nutrition'];

      totalCalories += (nutrition['calories'] ?? 0) * factor;
      totalCarbs += (nutrition['carbohydrate'] ?? 0) * factor;
      totalProtein += (nutrition['protein'] ?? 0) * factor;
      totalFat += (nutrition['fat'] ?? 0) * factor;
      totalSugar += (nutrition['sugar'] ?? 0) * factor;
      totalFiber += (nutrition['fiber'] ?? 0) * factor;
      totalSaturatedFat += (nutrition['saturatedfat'] ?? 0) * factor;
      totalCholesterol += (nutrition['cholesterol'] ?? 0) * factor;
      totalSodium += (nutrition['sodium'] ?? 0) * factor;
    }
  }

  void _removeIngredient(int index) {
    addedIngredients.removeAt(index);
    _calculateNutrition();
    setState(() {});
  }

  void _saveRecipe() async {
    final uuid = const Uuid().v4();
    final String name = recipeNameController.text.trim();
    final String instructions = instructionsController.text.trim();
    final int expiryDays = int.tryParse(expiryController.text.trim()) ?? 0;
    final String servings = servingsController.text.trim();
    final String recipeYield = yieldController.text.trim();
    final int prepMinutes = int.tryParse(prepTimeController.text.trim()) ?? 0;
    final int cookMinutes = int.tryParse(cookTimeController.text.trim()) ?? 0;
    final String category = categoryController.text.trim();
    final List<String> keywords = keywordsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    List<double> ingredientQuantities =
        addedIngredients.map((e) => e['weight'] as double).toList();
    List<String> ingredientParts =
        addedIngredients.map((e) => e['name'] as String).toList();

    final Map<String, dynamic> recipe = {
      "Id": uuid,
      "Name": name,
      "CookTime": 'PT${cookMinutes}M',
      "PrepTime": 'PT${prepMinutes}M',
      "TotalTime": 'PT${prepMinutes + cookMinutes}M',
      "Images": [],
      "ExpiryDate": expiryDays,
      "RecipeCategory": category,
      "Keywords": keywords,
      "RecipeIngredientQuantities": ingredientQuantities,
      "RecipeIngredientParts": ingredientParts,
      "AggregatedRating": 0,
      "ReviewCount": 0,
      "Calories": totalCalories,
      "ProteinContent": totalProtein,
      "CarbohydrateContent": totalCarbs,
      "FatContent": totalFat,
      "SaturatedFatContent": totalSaturatedFat,
      "CholesterolContent": totalCholesterol == 0 ? null : totalCholesterol,
      "SodiumContent": totalSodium == 0 ? null : totalSodium,
      "FiberContent": totalFiber,
      "SugarContent": totalSugar,
      "RecipeServings": servings,
      "RecipeYield": recipeYield,
      "RecipeInstructions": instructions,
    };

    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(uuid)
        .set(recipe);

    final userId = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .doc('created')
        .set({uuid: true}, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Recipe'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField('Recipe Name', recipeNameController),
            const SizedBox(height: 10),
            _buildTextField('Prep Time (minutes)', prepTimeController,
                isNumber: true),
            const SizedBox(height: 10),
            _buildTextField('Cook Time (minutes)', cookTimeController,
                isNumber: true),
            const SizedBox(height: 10),
            _buildTextField('Category (e.g. Salad)', categoryController),
            const SizedBox(height: 10),
            _buildTextField('Keywords (comma separated)', keywordsController),
            const SizedBox(height: 10),
            _buildTextField('Servings', servingsController),
            const SizedBox(height: 10),
            _buildTextField('Yield (e.g. 2 servings)', yieldController),
            const SizedBox(height: 10),
            _buildTextField('Days to Expiry', expiryController, isNumber: true),
            const SizedBox(height: 16),
            const Text('Nutrition Summary:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _buildNutrientChip('Calories', totalCalories),
                _buildNutrientChip('Carbs', totalCarbs),
                _buildNutrientChip('Protein', totalProtein),
                _buildNutrientChip('Fat', totalFat),
                _buildNutrientChip('Sugar', totalSugar),
                _buildNutrientChip('Fiber', totalFiber),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField('Search Ingredient', searchController,
                onSubmit: _searchIngredients),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Weight (g)'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _searchIngredients(searchController.text),
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading) const Center(child: CircularProgressIndicator()),
            if (!isLoading && searchResults.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final doc = searchResults[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['name']),
                    subtitle: Text('Calories: ${data['calories']} per 100g'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final weight = double.tryParse(weightController.text);
                        if (weight != null && weight > 0) {
                          _addIngredient(doc, weight);
                        }
                      },
                    ),
                  );
                },
              ),
            const SizedBox(height: 10),
            const Text('Added Ingredients:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...addedIngredients.map((ing) => Card(
                  child: ListTile(
                    title: Text(ing['name']),
                    subtitle: Text('${ing['weight']} grams'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _removeIngredient(addedIngredients.indexOf(ing)),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
            const Text('Instructions',
                style: TextStyle(fontWeight: FontWeight.w600)),
            TextField(
              controller: instructionsController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Enter cooking instructions...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveRecipe,
                child: const Text('Save Recipe'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumber = false, void Function(String)? onSubmit}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      onSubmitted: onSubmit,
    );
  }

  Widget _buildNutrientChip(String label, double value) {
    return Chip(
      label: Text('$label: ${value.toStringAsFixed(1)}'),
      backgroundColor: Colors.blue.shade50,
    );
  }
}

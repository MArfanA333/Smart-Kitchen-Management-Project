import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditRecipePage extends StatefulWidget {
  final String recipeId;
  final Map<String, dynamic> recipeData;

  const EditRecipePage(
      {super.key, required this.recipeId, required this.recipeData});

  @override
  State<EditRecipePage> createState() => _EditRecipePageState();
}

class _EditRecipePageState extends State<EditRecipePage> {
  late TextEditingController recipeNameController;
  late TextEditingController instructionsController;
  late TextEditingController expiryController;
  late TextEditingController servingsController;
  late TextEditingController yieldController;
  late TextEditingController prepTimeController;
  late TextEditingController cookTimeController;
  late TextEditingController categoryController;
  late TextEditingController keywordsController;

  @override
  void initState() {
    super.initState();
    recipeNameController =
        TextEditingController(text: widget.recipeData['Name']);
    instructionsController =
        TextEditingController(text: widget.recipeData['RecipeInstructions']);
    expiryController = TextEditingController(
        text: widget.recipeData['ExpiryDate']?.toString() ?? '');
    servingsController =
        TextEditingController(text: widget.recipeData['RecipeServings'] ?? '');
    yieldController =
        TextEditingController(text: widget.recipeData['RecipeYield'] ?? '');
    prepTimeController = TextEditingController(
        text:
            widget.recipeData['PrepTime']?.replaceAll(RegExp(r'\D'), '') ?? '');
    cookTimeController = TextEditingController(
        text:
            widget.recipeData['CookTime']?.replaceAll(RegExp(r'\D'), '') ?? '');
    categoryController =
        TextEditingController(text: widget.recipeData['RecipeCategory'] ?? '');
    keywordsController = TextEditingController(
      text: (widget.recipeData['Keywords'] as List?)?.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    recipeNameController.dispose();
    instructionsController.dispose();
    expiryController.dispose();
    servingsController.dispose();
    yieldController.dispose();
    prepTimeController.dispose();
    cookTimeController.dispose();
    categoryController.dispose();
    keywordsController.dispose();
    super.dispose();
  }

  void _saveEdits() async {
    final updatedRecipe = {
      "Name": recipeNameController.text.trim(),
      "RecipeInstructions": instructionsController.text.trim(),
      "ExpiryDate": int.tryParse(expiryController.text.trim()) ?? 0,
      "RecipeServings": servingsController.text.trim(),
      "RecipeYield": yieldController.text.trim(),
      "PrepTime": 'PT${prepTimeController.text.trim()}M',
      "CookTime": 'PT${cookTimeController.text.trim()}M',
      "TotalTime":
          'PT${(int.tryParse(prepTimeController.text.trim()) ?? 0) + (int.tryParse(cookTimeController.text.trim()) ?? 0)}M',
      "RecipeCategory": categoryController.text.trim(),
      "Keywords":
          keywordsController.text.split(',').map((e) => e.trim()).toList(),
    };

    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipeId)
        .update(updatedRecipe);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe updated successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Recipe'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField('Recipe Name', recipeNameController),
            _buildTextField('Prep Time (minutes)', prepTimeController,
                isNumber: true),
            _buildTextField('Cook Time (minutes)', cookTimeController,
                isNumber: true),
            _buildTextField('Category', categoryController),
            _buildTextField('Keywords (comma separated)', keywordsController),
            _buildTextField('Servings', servingsController),
            _buildTextField('Yield', yieldController),
            _buildTextField('Days to Expiry', expiryController, isNumber: true),
            const SizedBox(height: 16),
            const Align(
                alignment: Alignment.centerLeft, child: Text('Instructions:')),
            TextField(
              controller: instructionsController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Recipe instructions...',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveEdits,
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({Key? key}) : super(key: key);

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> shoppingList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchShoppingList();
  }

  Future<void> _logInteraction(String message) async {
    final logRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('logs')
        .doc('itemList')
        .collection('interaction');

    await logRef.add({
      'message': message,
      'date': Timestamp.now(),
    });
  }

  Future<void> _fetchShoppingList() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('shopping_list')
        .get();

    setState(() {
      shoppingList =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      isLoading = false;
    });
  }

  Future<void> _addIngredient(
      String name, double quantity, String reason) async {
    final normalized = name.trim().toLowerCase();

    final existingSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('shopping_list')
        .where('name', isEqualTo: normalized)
        .limit(1)
        .get();

    if (existingSnapshot.docs.isNotEmpty) {
      final doc = existingSnapshot.docs.first;
      final currentQty = doc['quantity'] ?? 0.0;
      final newQty = currentQty + quantity;
      final currentReason = doc['reason'] ?? '';
      final mergedReason = currentReason.contains(reason)
          ? currentReason
          : '$currentReason, $reason';

      await doc.reference.update({'quantity': newQty, 'reason': mergedReason});
      setState(() {
        final index = shoppingList.indexWhere((item) => item['id'] == doc.id);
        if (index != -1) {
          shoppingList[index]['quantity'] = newQty;
          shoppingList[index]['reason'] = mergedReason;
        }
      });
    } else {
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('shopping_list')
          .add({
        'name': normalized,
        'quantity': quantity,
        'purchased': false,
        'reason': reason,
      });

      setState(() {
        shoppingList.add({
          'id': docRef.id,
          'name': normalized,
          'quantity': quantity,
          'purchased': false,
          'reason': reason,
        });
      });
    }

    await _logInteraction('Added "$name" ($quantity) - $reason');
  }

  Future<void> _removeIngredient(String id) async {
    final item =
        shoppingList.firstWhere((e) => e['id'] == id, orElse: () => {});
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('shopping_list')
        .doc(id)
        .delete();
    setState(() {
      shoppingList.removeWhere((item) => item['id'] == id);
    });

    if (item.isNotEmpty) {
      await _logInteraction('Removed "${item['name']}" from shopping list.');
    }
  }

  Future<void> _togglePurchased(String id, bool current) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('shopping_list')
        .doc(id)
        .update({'purchased': !current});
    setState(() {
      final index = shoppingList.indexWhere((item) => item['id'] == id);
      if (index != -1) {
        shoppingList[index]['purchased'] = !current;
      }
    });

    final item =
        shoppingList.firstWhere((e) => e['id'] == id, orElse: () => {});
    if (item.isNotEmpty) {
      await _logInteraction(
          '${!current ? 'Checked off' : 'Unchecked'} "${item['name']}" on shopping list.');
    }
  }

  Future<void> _clearPurchasedItems() async {
    final purchasedItems =
        shoppingList.where((item) => item['purchased'] == true).toList();
    for (var item in purchasedItems) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('shopping_list')
          .doc(item['id'])
          .delete();
      await _logInteraction('Cleared purchased item: "${item['name']}"');
    }
    setState(() {
      shoppingList.removeWhere((item) => item['purchased'] == true);
    });
  }

  Future<void> _addFromRecipe() async {
    final recipeSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .doc('saved')
        .collection('collection')
        .get();

    List<Map<String, String>> allRecipes = [];

    for (var doc in recipeSnapshot.docs) {
      final List<dynamic> recipeIds = doc['recipes'] ?? [];
      for (String recipeId in recipeIds) {
        final recipeDoc = await FirebaseFirestore.instance
            .collection('recipes')
            .doc(recipeId)
            .get();
        if (recipeDoc.exists) {
          allRecipes.add({
            'id': recipeId,
            'name': recipeDoc.data()?['Name'] ?? 'Unnamed Recipe',
          });
        }
      }
    }

    String? selectedRecipeId;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select a Recipe'),
        content: DropdownButtonFormField<String>(
          isExpanded: true,
          items: allRecipes
              .map((r) => DropdownMenuItem(
                    value: r['id'],
                    child: Text(r['name']!),
                  ))
              .toList(),
          onChanged: (value) => selectedRecipeId = value,
          decoration: const InputDecoration(labelText: 'Recipe'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedRecipeId != null) {
                final recipeDoc = await FirebaseFirestore.instance
                    .collection('recipes')
                    .doc(selectedRecipeId)
                    .get();

                final recipeData = recipeDoc.data() ?? {};
                final ingredientNames = List<String>.from(
                    recipeData['RecipeIngredientParts'] ?? []);
                final ingredientQuantities = List<dynamic>.from(
                    recipeData['RecipeIngredientQuantities'] ?? []);
                final recipeName = recipeData['Name'] ?? 'Unnamed Recipe';

                for (int i = 0; i < ingredientNames.length; i++) {
                  await _addIngredient(
                    ingredientNames[i],
                    double.tryParse(ingredientQuantities[i].toString()) ?? 1,
                    'Added from recipe "$recipeName"',
                  );
                }

                await _logInteraction(
                    'Generated shopping list from recipe "$recipeName"');
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateFromMeals() async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    setState(() {
      isLoading = true;
    });

    try {
      for (String day in days) {
        final mealSnapshot = await userDoc
            .collection('meals')
            .doc(day)
            .collection('mealList')
            .get();

        for (final mealDoc in mealSnapshot.docs) {
          final mealData = mealDoc.data();
          final List<dynamic> recipeIds = mealData['recipes'] ?? [];

          for (String recipeId in recipeIds) {
            final recipeDoc = await FirebaseFirestore.instance
                .collection('recipes')
                .doc(recipeId)
                .get();

            if (recipeDoc.exists) {
              final recipeData = recipeDoc.data() ?? {};
              final List<dynamic> ingredientNames =
                  List.from(recipeData['RecipeIngredientParts'] ?? []);
              final List<dynamic> ingredientQuantities =
                  List.from(recipeData['RecipeIngredientQuantities'] ?? []);
              final recipeName = recipeData['Name'] ?? 'Unnamed Recipe';

              for (int i = 0; i < ingredientNames.length; i++) {
                await _addIngredient(
                  ingredientNames[i],
                  double.tryParse(ingredientQuantities[i].toString()) ?? 1,
                  'Added because of meal "$recipeName" on $day',
                );
              }
            }
          }
        }
      }

      await _logInteraction('Generated shopping list from weekly meal plan');
    } catch (e, stack) {
      print("Error generating meals: $e\n$stack");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _capitalizeWords(String input) {
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void _showAddManualDialog() {
    String name = '';
    String qtyStr = '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Ingredient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (val) => name = val,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              onChanged: (val) => qtyStr = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty && double.tryParse(qtyStr) != null) {
                _addIngredient(name, double.parse(qtyStr), 'Added manually');
                _logInteraction('Manually added "$name" to shopping list');
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shopping List"),
        actions: [
          IconButton(
            tooltip: "Clear Purchased",
            icon: const Icon(Icons.check_circle_outline),
            onPressed: shoppingList.any((e) => e['purchased'] == true)
                ? _clearPurchasedItems
                : null,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : shoppingList.isEmpty
              ? const Center(
                  child: Text(
                    "Your shopping list is empty!",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: shoppingList.length,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemBuilder: (context, index) {
                    final item = shoppingList[index];
                    final purchased = item['purchased'] == true;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      color: purchased ? Colors.green[50] : Colors.white,
                      child: ListTile(
                        onTap: () => _togglePurchased(item['id'], purchased),
                        leading: Checkbox(
                          activeColor: Colors.green,
                          value: purchased,
                          onChanged: (_) =>
                              _togglePurchased(item['id'], purchased),
                        ),
                        title: Text(
                          '${index + 1}. ${_capitalizeWords(item['name'])}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            decoration: purchased
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: purchased ? Colors.green[700] : Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quantity: ${item['quantity']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: purchased
                                    ? Colors.green[800]
                                    : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...((item['reason'] ?? "No reason").split(',').map(
                                  (r) => Text(
                                    r.trim(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: purchased
                                          ? Colors.green[800]
                                          : Colors.black45,
                                    ),
                                  ),
                                )),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeIngredient(item['id']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: PopupMenuButton<String>(
        icon: const Icon(Icons.add_shopping_cart),
        onSelected: (value) {
          if (value == 'manual') {
            _showAddManualDialog();
          } else if (value == 'recipe') {
            _addFromRecipe();
          } else if (value == 'meals') {
            _generateFromMeals();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'manual', child: Text('Add Manually')),
          const PopupMenuItem(value: 'recipe', child: Text('Add from Recipe')),
          const PopupMenuItem(
              value: 'meals', child: Text('Generate from Meals')),
        ],
      ),
    );
  }
}

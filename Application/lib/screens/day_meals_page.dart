import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'meal_detail_page.dart';

class DayMealsPage extends StatefulWidget {
  final String dayName;

  const DayMealsPage({super.key, required this.dayName});

  @override
  State<DayMealsPage> createState() => _DayMealsPageState();
}

class _DayMealsPageState extends State<DayMealsPage> {
  late CollectionReference mealCollection;
  late String userId;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser!.uid;
    mealCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('meals')
        .doc(widget.dayName)
        .collection('mealList');
  }

  Future<void> _logInteraction(String message) async {
    final interactionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('logs')
        .doc('itemList')
        .collection('interaction');

    await interactionRef.add({
      'date': DateTime.now(),
      'message': message,
    });
  }

  Future<void> _addMeal() async {
    String selectedType = 'Breakfast';
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Meal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedType,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedType = value);
                  }
                },
                items: ['Breakfast', 'Lunch', 'Dinner', 'Custom']
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
              ),
              if (selectedType == 'Custom')
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Meal Name',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                String mealName = selectedType != 'Custom'
                    ? selectedType
                    : nameController.text.trim();

                if (mealName.isNotEmpty) {
                  await mealCollection.add({
                    'name': mealName,
                    'recipes': [],
                    'order': DateTime.now().millisecondsSinceEpoch
                  });

                  await _logInteraction(
                      'Meal "$mealName" has been added to "${widget.dayName}".');
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateMealOrder(List<QueryDocumentSnapshot> docs) async {
    for (int i = 0; i < docs.length; i++) {
      await docs[i].reference.update({'order': i});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Meals for ${widget.dayName}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.lightBlue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: mealCollection.orderBy('order').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'No meals added yet.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              );
            }

            return ReorderableListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: docs.length,
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex--;
                final movedDoc = docs.removeAt(oldIndex);
                docs.insert(newIndex, movedDoc);
                await _updateMealOrder(docs);
              },
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;

                return Card(
                  key: ValueKey(doc.id),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    title: Text(
                      data['name'] ?? 'Unnamed Meal',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final mealName = data['name'] ?? 'Unnamed Meal';
                            await doc.reference.delete();
                            await _logInteraction(
                                'Meal "$mealName" has been removed from "${widget.dayName}".');
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios,
                              color: Colors.blueAccent),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MealDetailPage(
                                  userId: userId,
                                  dayName: widget.dayName,
                                  mealId: doc.id,
                                  mealData: data,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: _addMeal,
        child: const Icon(Icons.add),
      ),
    );
  }
}

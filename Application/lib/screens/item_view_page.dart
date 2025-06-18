import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'item_detail_screen.dart'; // Import the detail page

class ItemViewPage extends StatefulWidget {
  const ItemViewPage({super.key});

  @override
  _ItemViewPageState createState() => _ItemViewPageState();
}

class _ItemViewPageState extends State<ItemViewPage> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Center(
        child: Text(
          "User not logged in",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "All Items",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                labelText: "Search items",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // Item List
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('inventory')
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No items found",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                var items = snapshot.data!.docs
                    .where((doc) => (doc['name'] as String)
                        .toLowerCase()
                        .contains(searchQuery))
                    .toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    var item = items[index];
                    Map<String, dynamic> data =
                        item.data() as Map<String, dynamic>;

                    String itemId = item.id;
                    String itemName =
                        _capitalize(data['name'] ?? 'Unnamed Item');
                    String locationId = data['locationId'].toString();
                    double weight = (data['weight'] ?? 0.0).toDouble();
                    String category = data['category'] ?? 'ingredient';

                    IconData categoryIcon = _getCategoryIcon(category);

                    return FutureBuilder(
                      future: _fetchLocationName(userId, locationId),
                      builder: (context, AsyncSnapshot<String> locSnapshot) {
                        String locationName =
                            locSnapshot.data ?? 'Unknown Location';

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ItemDetailScreen(
                                    itemId: itemId, itemData: data),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(15),
                              leading: Icon(categoryIcon,
                                  color: Colors.blueAccent, size: 40),
                              title: Text(
                                itemName,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                  "📍 Location: $locationName\n⚖️ Weight: ${weight}g"),
                              trailing: const Icon(Icons.arrow_forward_ios,
                                  color: Colors.grey),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Fetches the name of the location based on locationId.
  Future<String> _fetchLocationName(String userId, String locationId) async {
    DocumentSnapshot locationDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('locations')
        .doc(locationId)
        .get();

    return locationDoc.exists
        ? (locationDoc['name'] ?? 'Unknown Location')
        : 'Unknown Location';
  }

  /// Capitalizes the first letter of each word in a string.
  String _capitalize(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Returns the correct icon based on the category.
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case "ingredient":
        return Icons.kitchen; // 🍳 Ingredient Icon
      case "meal":
        return Icons.restaurant; // 🍽️ Meal Icon
      default:
        return Icons.fastfood; // Default Food Icon 🍔
    }
  }
}

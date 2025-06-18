import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'location_items_screen.dart';

class StorageViewPage extends StatefulWidget {
  const StorageViewPage({super.key});

  @override
  _StorageViewPageState createState() => _StorageViewPageState();
}

class _StorageViewPageState extends State<StorageViewPage> {
  String searchQuery = "";

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
          "Storage Locations",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: InputDecoration(
                labelText: "Search Locations",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('locations')
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var locations = snapshot.data!.docs
                    .where((doc) => doc['name']
                        .toString()
                        .toLowerCase()
                        .contains(searchQuery))
                    .toList();

                if (locations.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    var location = locations[index];
                    String locationId = location.id;
                    String locationName =
                        location['name'] ?? 'Unnamed Location';
                    String category = location['category'] ?? '';
                    double temperature = location['temperature'];
                    double humidity = location['humidity']?.toDouble() ?? 0.0;

                    IconData locationIcon = _getCategoryIcon(category);
                    Map<String, dynamic> optimalValues =
                        _getOptimalValues(category);

                    return FutureBuilder(
                      future: _fetchTopItems(userId, locationId),
                      builder:
                          (context, AsyncSnapshot<List<String>> itemSnapshot) {
                        List<String> itemNames = itemSnapshot.data ?? [];

                        return Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(15),
                            leading: Icon(locationIcon,
                                color: Colors.blueAccent, size: 40),
                            title: Text(
                              locationName,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                        "🌡 Temp: ${temperature.toStringAsFixed(1)}°C "),
                                    _getIndicator(
                                        temperature,
                                        optimalValues['tempMin'],
                                        optimalValues['tempMax']),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                        "💧 Humidity: ${humidity.toStringAsFixed(1)}% "),
                                    _getIndicator(
                                        humidity,
                                        optimalValues['humidityMin'],
                                        optimalValues['humidityMax']),
                                  ],
                                ),
                                if (itemNames.isNotEmpty)
                                  Text("📦 Items: ${itemNames.join(', ')}"),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                color: Colors.blueAccent),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LocationItemsScreen(
                                    userId: userId,
                                    locationId: locationId,
                                    locationName: locationName,
                                    category: category,
                                  ),
                                ),
                              );
                            },
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

  /// Fetches the top 2 heaviest items for a given location.
  Future<List<String>> _fetchTopItems(String userId, String locationId) async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .where("locationId", isEqualTo: int.parse(locationId))
        .limit(2)
        .get();
    return querySnapshot.docs.map((doc) => doc['name'].toString()).toList();
  }

  /// Returns the correct icon based on the category.
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case "freezer":
        return Icons.ac_unit; // Freezer ❄️
      case "fridge":
        return Icons.kitchen; // Fridge 🧊
      case "cabinet":
        return Icons.kitchen_outlined; // Cabinet 🚪
      default:
        return Icons.warehouse; // Default 🏭
    }
  }

  /// Returns the optimal temperature and humidity ranges based on category.
  Map<String, dynamic> _getOptimalValues(String category) {
    switch (category.toLowerCase()) {
      case "freezer":
        return {
          "tempMin": -18.0,
          "tempMax": -15.0,
          "humidityMin": 30.0,
          "humidityMax": 50.0
        };
      case "fridge":
        return {
          "tempMin": 2.0,
          "tempMax": 6.0,
          "humidityMin": 30.0,
          "humidityMax": 50.0
        };
      case "cabinet":
        return {
          "tempMin": 18.0,
          "tempMax": 22.0,
          "humidityMin": 40.0,
          "humidityMax": 60.0
        };
      default:
        return {
          "tempMin": 0.0,
          "tempMax": 50.0,
          "humidityMin": 0.0,
          "humidityMax": 100.0
        }; // Fallback
    }
  }

  /// Returns an indicator (✅ or ⚠️) based on whether the value is within the optimal range.
  Widget _getIndicator(double value, double min, double max) {
    return Text(
      (value >= min && value <= max) ? " ✅" : " ⚠️",
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: (value >= min && value <= max) ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text(
            "No locations found",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

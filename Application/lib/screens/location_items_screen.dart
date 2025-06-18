import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_detail_screen.dart';

class LocationItemsScreen extends StatefulWidget {
  final String userId;
  final String locationId;
  final String locationName;
  final String category;

  const LocationItemsScreen({
    super.key,
    required this.userId,
    required this.locationId,
    required this.locationName,
    required this.category,
  });

  @override
  _LocationItemsScreenState createState() => _LocationItemsScreenState();
}

class _LocationItemsScreenState extends State<LocationItemsScreen> {
  String searchQuery = '';

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
        };
    }
  }

  void _showConditionDialog(
      String type, double currentValue, double min, double max) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(type == 'Temperature' ? Icons.thermostat : Icons.water_drop,
                  color: Colors.blueAccent),
              const SizedBox(width: 10),
              Text('$type Alert'),
            ],
          ),
          content: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              children: [
                TextSpan(text: "⚠️ The current $type is "),
                TextSpan(
                  text: "${currentValue.toStringAsFixed(1)}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red),
                ),
                TextSpan(text: type == 'Temperature' ? "°C" : "%"),
                const TextSpan(
                    text: ", which is outside the optimal range.\n\n"),
                const TextSpan(text: "✅ Ideal range: "),
                TextSpan(
                  text: "${min.toStringAsFixed(1)} - ${max.toStringAsFixed(1)}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green),
                ),
                TextSpan(text: type == 'Temperature' ? "°C" : "%"),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Got it!",
                  style: TextStyle(color: Colors.blueAccent)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case "ingredient":
        return Icons.kitchen;
      case "meal":
        return Icons.restaurant;
      default:
        return Icons.fastfood;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Items in ${widget.locationName}",
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 2,
      ),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .collection('locations')
                .doc(widget.locationId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists)
                return const SizedBox();

              var locationData = snapshot.data!.data() as Map<String, dynamic>?;
              double temperature =
                  (locationData?['temperature'] ?? 0.0).toDouble();
              double humidity = (locationData?['humidity'] ?? 0.0).toDouble();
              double alcoholLevel =
                  (locationData?['alcohol_level'] ?? 0.0).toDouble();
              double weight = (locationData?['weight'] ?? 0.0).toDouble();

              var optimal = _getOptimalValues(widget.category);
              bool isTempOptimal = temperature >= optimal["tempMin"] &&
                  temperature <= optimal["tempMax"];
              bool isHumidityOptimal = humidity >= optimal["humidityMin"] &&
                  humidity <= optimal["humidityMax"];

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.locationName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                            "🌡 Temperature: ${temperature.toStringAsFixed(1)}°C"),
                        const SizedBox(width: 5),
                        GestureDetector(
                          onTap: () {
                            if (!isTempOptimal) {
                              _showConditionDialog(
                                'Temperature',
                                temperature,
                                optimal["tempMin"],
                                optimal["tempMax"],
                              );
                            }
                          },
                          child: Text(
                            isTempOptimal ? "✅ Good" : "⚠️ Warning",
                            style: TextStyle(
                              color: isTempOptimal ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              decoration: !isTempOptimal
                                  ? TextDecoration.underline
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text("💧 Humidity: ${humidity.toStringAsFixed(1)}%"),
                        const SizedBox(width: 5),
                        GestureDetector(
                          onTap: () {
                            if (!isHumidityOptimal) {
                              _showConditionDialog(
                                'Humidity',
                                humidity,
                                optimal["humidityMin"],
                                optimal["humidityMax"],
                              );
                            }
                          },
                          child: Text(
                            isHumidityOptimal ? "✅ Good" : "⚠️ Warning",
                            style: TextStyle(
                              color:
                                  isHumidityOptimal ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              decoration: !isHumidityOptimal
                                  ? TextDecoration.underline
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                        "🍷 Alcohol Level: ${alcoholLevel.toStringAsFixed(2)}"),
                    Text("⚖️ Current Weight: ${weight.toStringAsFixed(1)} g"),
                  ],
                ),
              );
            },
          ),
          const Divider(thickness: 1, height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search items...",
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (value) =>
                  setState(() => searchQuery = value.toLowerCase()),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .collection('inventory')
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return _buildEmptyState();

                var items = snapshot.data!.docs
                    .where((doc) => doc.id.contains("_${widget.locationId}"))
                    .where((doc) => (doc['name'] as String)
                        .toLowerCase()
                        .contains(searchQuery))
                    .toList();

                if (items.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    var itemData = items[index].data() as Map<String, dynamic>;
                    String fullItemId = items[index].id;
                    String itemId = fullItemId.split("_")[0];
                    String name =
                        capitalizeWords(itemData['name'] ?? 'Unnamed Item');
                    String category = itemData['category'] ?? 'ingredient';
                    IconData categoryIcon = _getCategoryIcon(category);
                    double weight = (itemData['weight'] ?? 0.0).toDouble();
                    DateTime? expiryDate = itemData['expiry_date']?.toDate();

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: Icon(categoryIcon,
                            color: Colors.blueAccent, size: 40),
                        title: Text(name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("⚖ Weight: ${weight.toStringAsFixed(1)} g"),
                            if (expiryDate != null)
                              Text(
                                  "⏳ Expiry: ${expiryDate.toLocal().toString().split(' ')[0]}"),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            color: Colors.blueAccent),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ItemDetailScreen(
                                  itemId: itemId, itemData: itemData),
                            ),
                          );
                        },
                      ),
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
}

String capitalizeWords(String text) {
  return text
      .split(' ')
      .map((word) => word.isEmpty
          ? word
          : word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

Widget _buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inventory, size: 80, color: Colors.grey.shade400),
        const SizedBox(height: 10),
        const Text(
          "No items found in this location",
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black54),
        ),
      ],
    ),
  );
}

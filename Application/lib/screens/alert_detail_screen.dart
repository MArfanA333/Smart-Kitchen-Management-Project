import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'item_detail_screen.dart';
import 'location_items_screen.dart';

class AlertDetailScreen extends StatelessWidget {
  final String alertId;
  final Map<String, dynamic> alertData;

  const AlertDetailScreen({
    Key? key,
    required this.alertId,
    required this.alertData,
  }) : super(key: key);

  Color urgencyColor(String urgency) {
    switch (urgency) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Details'),
        backgroundColor: Colors.blueAccent,
      ),
      backgroundColor: Colors.blueGrey[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 5,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: urgencyColor(alertData['urgency']),
                      radius: 10,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        alertData['subject'],
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  alertData['message'],
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                Text(
                  'Date: ${(alertData['createdAt'] as Timestamp).toDate().toString().split('.')[0]}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const Spacer(),
                if (alertData['type'] == 'location' ||
                    alertData['type'] == 'item')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (user == null) return;

                        final type = alertData['type'];
                        final relatedId = alertData['id'];

                        if (type == 'location') {
                          final locationSnapshot = await FirebaseFirestore
                              .instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('locations')
                              .doc(relatedId)
                              .get();

                          if (locationSnapshot.exists) {
                            final locationData = locationSnapshot.data()!;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LocationItemsScreen(
                                  userId: user.uid,
                                  locationId: relatedId,
                                  locationName: locationData['name'],
                                  category: locationData['category'],
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Location not found!')),
                            );
                          }
                        } else if (type == 'item') {
                          final parts = relatedId.split('_');
                          final itemId = parts[0];

                          final itemSnapshot = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('inventory')
                              .doc(relatedId)
                              .get();

                          if (itemSnapshot.exists) {
                            final itemData = itemSnapshot.data()!;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ItemDetailScreen(
                                  itemId: itemId,
                                  itemData: itemData,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Item not found!')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: Text(
                        alertData['type'] == 'location'
                            ? 'View Location'
                            : 'View Item',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Back to Alerts"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 19, 149, 214),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (user == null) return;
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('alerts')
                          .doc(alertId)
                          .delete();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text("Delete Alert"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

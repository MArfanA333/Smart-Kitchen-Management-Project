import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'alert_detail_screen.dart';

class AlertsScreen extends StatelessWidget {
  AlertsScreen({Key? key}) : super(key: key);

  Color urgencyColor(String urgency) {
    switch (urgency) {
      case 'high':
        return Colors.red.shade400;
      case 'medium':
        return Colors.orange.shade400;
      case 'low':
        return Colors.yellow.shade700;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Alerts"),
        backgroundColor: Colors.blue,
      ),
      backgroundColor: const Color(0xFFF0F4F8), // Light bluish-gray
      body: userId == null
          ? const Center(child: Text("User not logged in."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('alerts')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No alerts yet.",
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                final alerts = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    final urgency = alert['urgency'] ?? 'none';
                    final isRead = alert['read'] ?? false;
                    final createdAt = alert['createdAt'] as Timestamp;
                    final createdAtStr = createdAt
                        .toDate()
                        .toString()
                        .split('.')[0]
                        .replaceAll('T', ' ');

                    return Dismissible(
                      key: Key(alert.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .collection('alerts')
                            .doc(alert.id)
                            .delete();
                      },
                      child: Card(
                        color: isRead ? Colors.grey[200] : Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: urgencyColor(urgency),
                          ),
                          title: Text(
                            alert['subject'] ?? 'No Subject',
                            style: TextStyle(
                              fontWeight:
                                  isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            alert['message'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            createdAtStr,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            // Mark as read
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .collection('alerts')
                                .doc(alert.id)
                                .update({'read': true});

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AlertDetailScreen(
                                  alertId: alert.id,
                                  alertData:
                                      alert.data() as Map<String, dynamic>,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ItemLogPage extends StatelessWidget {
  const ItemLogPage({Key? key}) : super(key: key);

  Map<String, List<QueryDocumentSnapshot>> groupLogsByDate(
      List<QueryDocumentSnapshot> docs) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};
    final now = DateTime.now();

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['date'] as Timestamp?;
      final date = timestamp?.toDate();

      if (date == null) continue;

      String group;
      final difference = now.difference(date).inDays;

      if (difference == 0) {
        group = 'Today';
      } else if (difference == 1) {
        group = 'Yesterday';
      } else if (difference < 7) {
        group = 'This Week';
      } else {
        group =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }

      grouped.putIfAbsent(group, () => []).add(doc);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final logsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('logs')
        .doc('itemList')
        .collection('inventory')
        .orderBy('date', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Item Log')),
      body: StreamBuilder<QuerySnapshot>(
        stream: logsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
                child:
                    Text("No logs yet!", style: TextStyle(color: Colors.grey)));
          }

          final groupedLogs = groupLogsByDate(docs);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: groupedLogs.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...entry.value.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final message = data['message'] ?? '';
                    final date = (data['date'] as Timestamp).toDate();
                    final formatted = DateFormat('HH:mm').format(date);

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title:
                            Text(message, style: const TextStyle(fontSize: 16)),
                        subtitle: Text(formatted,
                            style: const TextStyle(color: Colors.grey)),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

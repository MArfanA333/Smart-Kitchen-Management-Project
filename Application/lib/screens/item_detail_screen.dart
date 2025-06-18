import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ItemDetailScreen extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;

  const ItemDetailScreen({
    super.key,
    required this.itemId,
    required this.itemData,
  });

  @override
  _ItemDetailScreenState createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late DateTime? expiryDate;
  late DateTime? reminderDate;
  late bool isEstimated;

  @override
  void initState() {
    super.initState();
    expiryDate = (widget.itemData['expiry_date'] as Timestamp?)?.toDate();
    reminderDate = (widget.itemData['reminder_date'] as Timestamp?)?.toDate();
    isEstimated = widget.itemData['expiry_estimated'] == true;
  }

  Future<void> _selectDate(BuildContext context, bool isExpiry) async {
    DateTime initialDate = isExpiry
        ? (expiryDate ?? DateTime.now())
        : (reminderDate ?? DateTime.now());
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isExpiry) {
          expiryDate = picked;
        } else {
          reminderDate = picked;
        }
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc('YOUR_USER_ID') // Replace with your user ID logic
          .collection('inventory')
          .doc(widget.itemId)
          .update({
        isExpiry ? 'expiry_date' : 'reminder_date': Timestamp.fromDate(picked),
      });
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return "N/A";
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.lightBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          capitalize(widget.itemData['name']),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "General Info",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent),
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                    Icons.scale, "Weight", "${widget.itemData['weight']} g"),
                _buildDetailRow(Icons.date_range, "Date Added",
                    formatTimestamp(widget.itemData['date_added'])),
                const Divider(height: 30),
                const Text(
                  "Dates",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent),
                ),
                const SizedBox(height: 10),
                _buildDatePickerRow(
                  icon: Icons.calendar_today,
                  label: "Expiry Date",
                  date: expiryDate,
                  isEstimated: isEstimated,
                  onTap: () => _selectDate(context, true),
                ),
                _buildDatePickerRow(
                  icon: Icons.alarm,
                  label: "Reminder Date",
                  date: reminderDate,
                  isEstimated: false,
                  onTap: () => _selectDate(context, false),
                ),
                const SizedBox(height: 30),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new),
                    label: const Text("Back to Inventory"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 28),
          const SizedBox(width: 14),
          Text(
            "$title:",
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerRow({
    required IconData icon,
    required String label,
    required DateTime? date,
    required bool isEstimated,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueAccent, size: 28),
            const SizedBox(width: 14),
            Text(
              "$label:",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "${formatDate(date)} ${isEstimated && label == 'Expiry Date' ? '(Estimated)' : ''}",
                style: const TextStyle(
                  fontSize: 17,
                  color: Colors.black87,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Icon(Icons.edit, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    }
    return "N/A";
  }

  String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

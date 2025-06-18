// profile_settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  _ProfileSettingsPageState createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  late String userId;
  String name = "";
  String email = "";
  String photoUrl = "";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        name = doc.data()?['name'] ?? "";
        email = user.email ?? "";
        photoUrl = doc.data()?['photoUrl'] ?? "";
      });
    }
  }

  Future<void> _updateName() async {
    final controller = TextEditingController(text: name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Name"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({'name': newName});
                setState(() {
                  name = newName;
                });
              }
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfilePicture() async {
    // Placeholder for profile picture update logic
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Profile picture update not implemented.")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile Settings"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Your User ID",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            SelectableText(
              userId,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _updateProfilePicture,
              child: CircleAvatar(
                radius: 40,
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              title: const Text("Name"),
              subtitle: Text(name),
              trailing: const Icon(Icons.edit),
              onTap: _updateName,
            ),
            ListTile(
              title: const Text("Email"),
              subtitle: Text(email),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: const Text("Toggle Dark/Light Mode (Coming Soon)"),
            )
          ],
        ),
      ),
    );
  }
}

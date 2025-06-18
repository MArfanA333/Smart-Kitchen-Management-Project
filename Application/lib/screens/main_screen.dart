import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'inventory_screen.dart';
import 'recipes_screen.dart';
import 'shopping_list_screen.dart';
import 'alerts_screen.dart';
import 'settings_screen.dart';
import 'meal_planner_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String userName = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final nameFromFirestore = doc.data()?['name'] ?? "User";
      setState(() {
        userName = nameFromFirestore;
      });
    } else {
      setState(() {
        userName = "User";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: Text(
          "Welcome, $userName",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            _buildGreetingCard(),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildNavigationCard(
                      "Inventory", Icons.inventory, InventoryScreen()),
                  _buildNavigationCard(
                      "Recipes", Icons.restaurant_menu, RecipeScreen()),
                  _buildNavigationCard("Shopping List", Icons.shopping_cart,
                      ShoppingListScreen()),
                  _buildNavigationCard(
                      "Meal Planner", Icons.fastfood, MealPlannerPage()),
                  _buildAlertsCard(), // Special case for Alerts with StreamBuilder
                  _buildNavigationCard(
                      "Settings", Icons.settings, SettingsScreen()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.blueAccent,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.person, size: 50, color: Colors.white),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                "Hello, $userName! 👋\nWhat would you like to do today?",
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(String title, IconData icon, Widget page,
      {int badgeCount = 0}) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => page));
        },
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 50, color: Colors.blueAccent),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsCard() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildNavigationCard(
          "Alerts", Icons.notifications, AlertsScreen());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alerts')
          .where('seen', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unseenCount = 0;
        if (snapshot.hasData) {
          unseenCount = snapshot.data!.docs.length;
        }
        return _buildNavigationCard(
            "Alerts", Icons.notifications, AlertsScreen(),
            badgeCount: unseenCount);
      },
    );
  }
}

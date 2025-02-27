import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'forecast.dart';
import 'analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = "http://127.0.0.1:5000";

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

Future<String?> _getToken() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('token'); // Retrieve the stored token
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    InventoryScreen(),
    ForecastResultsScreen(),
    AnalyticsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Dashboard",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: "Inventory",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: "Forecast",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: "Analytics",
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: _onItemTapped,
      ),
    );
  }
}

class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _inventory = [];

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    final String? token = await _getToken();
    print("Token: $token"); // Debug: Print the retrieved token

    if (token == null) {
      print("Error: Token is null");
      return;
    }

    final response = await http.get(
      Uri.parse("$baseUrl/inventory"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("Response Code: ${response.statusCode}");
    print("Response Body: ${response.body}"); // Debug response

    if (response.statusCode == 200) {
      setState(() {
        _inventory = List<Map<String, dynamic>>.from(json.decode(response.body));
      });
    } else {
      print("Error fetching inventory: ${response.body}");
    }
  }

  Future<void> _addInventoryItem(String name, double price, int amount, String imageUrl) async {
    final String? token = await _getToken();
    print("Token: $token"); // Debug: Print the retrieved token

    if (token == null) {
      print("Error: Token is null");
      return;
    }

    final Map<String, dynamic> requestBody = {
      "item_name": name,
      "price": price,
      "quantity": amount,
      "image_url": imageUrl,
    };

    print("Sending data: ${jsonEncode(requestBody)}");

    final response = await http.post(
      Uri.parse("$baseUrl/inventory"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(requestBody),
    );

    print("Response Code: ${response.statusCode}");
    print("Response Body: ${response.body}");

    if (response.statusCode == 201) {
      _fetchInventory();
    } else {
      print("Error adding item: ${response.body}");
    }
  }

  Future<void> _updateInventoryItem(int itemId, int newQuantity) async {
    final String? token = await _getToken();
    if (token == null) {
      print("Error: Token is null");
      return;
    }

    final Map<String, dynamic> updateData = {
      "quantity": newQuantity,
    };

    final response = await http.put(
      Uri.parse("$baseUrl/inventory/$itemId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(updateData),
    );

    print("Update Response Code: ${response.statusCode}");
    print("Update Response Body: ${response.body}");

    if (response.statusCode == 200) {
      _fetchInventory();
    } else {
      print("Error updating item: ${response.body}");
    }
  }

  void _showAddInventoryDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    final TextEditingController imageUrlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Inventory Item"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(nameController, "Item Name", Icons.inventory),
              _buildTextField(priceController, "Price", Icons.attach_money, isNumber: true),
              _buildTextField(amountController, "Amount", Icons.production_quantity_limits, isNumber: true),
              _buildTextField(imageUrlController, "Image URL", Icons.image),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    priceController.text.isNotEmpty &&
                    amountController.text.isNotEmpty &&
                    imageUrlController.text.isNotEmpty) {
                  _addInventoryItem(
                    nameController.text,
                    double.parse(priceController.text),
                    int.parse(amountController.text),
                    imageUrlController.text,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text("Add Item"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _inventory.isEmpty
            ? const Center(
          child: Text(
            "No inventory items yet. Add some!",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        )
            : ListView.builder(
          itemCount: _inventory.length,
          itemBuilder: (context, index) {
            final item = _inventory[index];
            return Card(
              elevation: 5,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: item["image_url"] is String && (item["image_url"] as String).isNotEmpty
                    ? Image.network(item["image_url"] as String, width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.inventory, color: Colors.blueAccent),
                title: Text(item["item_name"], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Price: \$${item["price"]} • Amount: ${item["quantity"]}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.red),
                      onPressed: () {
                        int currentQuantity = item["quantity"];
                        if (currentQuantity > 0) {
                          _updateInventoryItem(item["id"], currentQuantity - 1);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.green),
                      onPressed: () {
                        int currentQuantity = item["quantity"];
                        _updateInventoryItem(item["id"], currentQuantity + 1);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddInventoryDialog,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
    );
  }
}

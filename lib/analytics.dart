import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsScreen extends StatefulWidget {
  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Future<List<dynamic>>? _inventoryData;

  Future<List<dynamic>> fetchInventoryData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception("No token found");

    final response = await http.get(
      Uri.parse("http://127.0.0.1:5000/inventory"),
      headers: {
        "Content-Type": "application/json",
        // Removed extra dot before $token.
        "Authorization": "Bearer $token"
      },
    );

    if (response.statusCode == 200) {
      // Assuming the inventory endpoint returns a JSON array of inventory items.
      // Each item should have "item_name" and "quantity" (available stock).
      return json.decode(response.body);
    } else {
      throw Exception("Failed to fetch inventory data");
    }
  }

  @override
  void initState() {
    super.initState();
    _inventoryData = fetchInventoryData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<dynamic>>(
        future: _inventoryData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}",
                  style: TextStyle(color: Colors.red, fontSize: 16)),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No inventory data available."));
          } else {
            final inventory = snapshot.data!;
            // Build bar chart data from inventory:
            List<BarChartGroupData> barGroups = [];
            double maxY = 0;
            int index = 0;
            for (var item in inventory) {
              // Assuming each item has "item_name" and "quantity" (available stock)
              double quantity = (item["quantity"] ?? 0).toDouble();
              if (quantity > maxY) maxY = quantity;
              barGroups.add(
                BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: quantity,
                      color: Colors.green,
                      width: 15,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              );
              index++;
            }
            // Add some padding on the top of the chart
            maxY = maxY * 1.2;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text("Available Stock by Product",
                      style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: maxY / 5,
                              getTitlesWidget: (value, meta) => Text(
                                value.toStringAsFixed(0),
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              // Return just a Text widget for each bottom title.
                              getTitlesWidget: (double value, TitleMeta meta) {
                                int i = value.toInt();
                                if (i >= 0 && i < inventory.length) {
                                  return Text(
                                    inventory[i]["item_name"].toString(),
                                    style: TextStyle(fontSize: 10),
                                    textAlign: TextAlign.center,
                                  );
                                }
                                return Container();
                              },
                              interval: 1,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        groupsSpace: 12,
                        barGroups: barGroups,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

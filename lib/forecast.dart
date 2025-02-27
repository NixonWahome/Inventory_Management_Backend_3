import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ForecastResultsScreen extends StatefulWidget {
  @override
  _ForecastResultsScreenState createState() => _ForecastResultsScreenState();
}

class _ForecastResultsScreenState extends State<ForecastResultsScreen> {
  Future<Map<String, dynamic>>? forecastData;

  Future<Map<String, dynamic>> fetchForecastResults() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token == null) {
      throw Exception("No token found. Please log in.");
    }
    final response = await http.get(
      Uri.parse("http://127.0.0.1:5000/forecast-results"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load forecast results");
    }
  }

  @override
  void initState() {
    super.initState();
    forecastData = fetchForecastResults();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: FutureBuilder<Map<String, dynamic>>(
        future: forecastData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}",
                  style: TextStyle(color: Colors.red, fontSize: 16)),
            );
          } else if (snapshot.hasData) {
            final data = snapshot.data!;
            final overallMSE = data['overall_mse'];
            final overallR2 = data['overall_r2'];
            final List<dynamic> results = data['forecast_results'];

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Overall Metrics Section
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      color: Colors.blue[50],
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              "Overall Model Metrics",
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Mean Squared Error: ${overallMSE.toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "R² Score: ${overallR2.toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Chart Section (for top 5 products)
                    Text(
                      "Forecast Chart (Top 5 Products)",
                      style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    Container(
                      height: 300,
                      child: ForecastChart(results: results),
                    ),
                    SizedBox(height: 20),
                    // Forecast Details List Section
                    Text(
                      "Forecast Details by Product",
                      style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final item = results[index];
                        return Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          margin: EdgeInsets.symmetric(vertical: 8),
                          elevation: 4,
                          child: ListTile(
                            contentPadding: EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              radius: 25,
                              child: Text(
                                item['Product ID'].toString(),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              "${item['Product ID']} - ${item['Category']}",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      "Actual Units Sold: ${item['Actual Units Sold']}"),
                                  Text(
                                      "Predicted Units Sold: ${item['Predicted Units Sold'].toStringAsFixed(2)}"),
                                  Text(
                                      "Accuracy: ${item['Accuracy (%)'].toStringAsFixed(2)}%"),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }
          return Container();
        },
      ),
    );
  }
}

// Custom chart widget using fl_chart to display forecast for top 5 products.
class ForecastChart extends StatelessWidget {
  final List<dynamic> results;

  ForecastChart({required this.results});

  @override
  Widget build(BuildContext context) {
    // Limit to top 5 products for chart clarity.
    final chartData = results.take(5).toList();
    double maxY = 0;
    chartData.forEach((item) {
      double actual = (item['Actual Units Sold'] as num).toDouble();
      double predicted = (item['Predicted Units Sold'] as num).toDouble();
      if (actual > maxY) maxY = actual;
      if (predicted > maxY) maxY = predicted;
    });
    maxY = maxY * 1.2; // Add padding for visual clarity

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxY / 5,
              getTitlesWidget: (value, meta) =>
                  Text(value.toStringAsFixed(0), style: TextStyle(fontSize: 12)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                int index = value.toInt();
                if (index < chartData.length) {
                  return Text(chartData[index]['Product ID'].toString(),
                      style: TextStyle(fontSize: 12));
                }
                return Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        groupsSpace: 12,
        barGroups: chartData.asMap().entries.map((entry) {
          int index = entry.key;
          var item = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              // Actual Units Sold bar
              BarChartRodData(
                toY: (item['Actual Units Sold'] as num).toDouble(),
                color: Colors.blue,
                width: 8,
              ),
              // Predicted Units Sold bar
              BarChartRodData(
                toY: (item['Predicted Units Sold'] as num).toDouble(),
                color: Colors.green,
                width: 8,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

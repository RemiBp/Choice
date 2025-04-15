import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// TODO: Define or import a proper data model if this widget is used.
// Replaced EngagementPoint with dynamic for now to fix compile errors.

class TrendChart extends StatelessWidget {
  final List<dynamic> data; // Changed from List<EngagementPoint>
  final String metric; // e.g., 'likes', 'comments', 'shares', 'posts'
  final String title;

  const TrendChart({
    Key? key,
    required this.data,
    required this.metric,
    required this.title,
  }) : super(key: key);

  double _getValue(dynamic point) {
    // Use safe map access, assuming point is map-like
    if (point is Map) {
       final value = point[metric];
       if (value is num) {
          return value.toDouble();
       }
    }
    // Fallback or handle other types if necessary
    print('Warning: Could not get metric "$metric" from point: $point');
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text('No data for $title'));
    }

    List<FlSpot> spots = [];
    Map<double, String> bottomTitles = {};
    double minY = double.maxFinite;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      final value = _getValue(point);
      spots.add(FlSpot(i.toDouble(), value));

      if (value < minY) minY = value;
      if (value > maxY) maxY = value;

      // Try to extract date for labels, assuming 'date' field exists
      String dateLabel = 'P${i+1}'; // Default label
      if (point is Map && point.containsKey('date') && point['date'] is String) {
         try {
           DateTime parsedDate = DateTime.parse(point['date']);
           dateLabel = DateFormat.Md('fr_FR').format(parsedDate);
         } catch (e) {
            dateLabel = point['date']; // Fallback to raw string
         }
      }
       if (i == 0 || i == data.length - 1 || i == (data.length / 2).floor()) {
         bottomTitles[i.toDouble()] = dateLabel;
       }
    }

    // Adjust Y-axis padding
    if (minY == maxY) {
      maxY += 1;
      minY = (minY > 0) ? minY - 1 : 0; // Adjust min if possible
    } else {
       double padding = (maxY - minY) * 0.1;
       maxY += padding;
       minY -= padding;
    }
     if (minY < 0 && data.every((p) => _getValue(p) >= 0)) {
        minY = 0; // Prevent negative axis if all data is non-negative
     }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Container(
            height: 250,
            padding: EdgeInsets.only(right: 16, top: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withOpacity(0.03),
            ),
            child: spots.isEmpty
                ? Center(child: Text('No data points'))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: (maxY > minY) ? (maxY - minY) / 4 : 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.2),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              return bottomTitles.containsKey(value)
                                  ? SideTitleWidget(
                                      meta: meta,
                                      space: 8.0,
                                      child: Text(bottomTitles[value]!, style: TextStyle(color: Colors.grey.shade700, fontSize: 10)),
                                    )
                                  : Container();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.min || value == meta.max || (value > meta.min && value < meta.max && (value - meta.min) / (meta.max - meta.min) > 0.45 && (value - meta.min) / (meta.max - meta.min) < 0.55)) {
                                return Text(NumberFormat.compact().format(value), style: TextStyle(color: Colors.grey.shade700, fontSize: 10), textAlign: TextAlign.left);
                              }
                              return Container();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (spots.length - 1).toDouble(),
                      minY: minY,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [Theme.of(context).primaryColor, Theme.of(context).colorScheme.secondary],
                          ),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor.withOpacity(0.3),
                                Theme.of(context).colorScheme.secondary.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                         touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (touchedSpot) => Colors.blueGrey.withOpacity(0.8),
                                getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                                  return touchedBarSpots.map((barSpot) {
                                     final flSpot = barSpot;
                                     final pointIndex = flSpot.x.toInt();
                                     String dateStr = '';
                                     if (pointIndex >= 0 && pointIndex < data.length) {
                                        final point = data[pointIndex];
                                        if (point is Map && point.containsKey('date') && point['date'] is String) {
                                           dateStr = point['date'];
                                        }
                                     }
                                    return LineTooltipItem(
                                      '${NumberFormat.compact().format(flSpot.y)}\n${dateStr}',
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                       textAlign: TextAlign.center,
                                    );
                                  }).toList();
                                 }
                              )
                            )
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Remove the old EngagementChart if it's no longer needed or refactor it similarly
/*
class EngagementChart extends StatelessWidget {
  final List<EngagementPoint> data;
  final String title;

  const EngagementChart({Key? key, required this.data, required this.title}) : super(key: key);

  int _getValue(EngagementPoint point) {
    // Placeholder - adapt based on actual data structure if needed
    return 0;
  }

  @override
  Widget build(BuildContext context) {
     // ... (Implementation similar to TrendChart using BarChart or LineChart)
     return Container(); // Placeholder
  }
}
*/ 
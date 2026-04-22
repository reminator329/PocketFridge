import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/datamodel.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<FoodItem>> _events = {};

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  DateTime _normalize(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  /// 🔥 Load Firestore data
  Future<void> _loadFoods() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    /// 🧩 1. get allowed fridges
    final fridgeSnapshot = await FirebaseFirestore.instance
        .collection('fridge_users')
        .where('userId', isEqualTo: userId)
        .get();

    final fridgeIds = fridgeSnapshot.docs
        .map((d) => d['fridgeId'] as String)
        .toList();

    if (fridgeIds.isEmpty) {
      setState(() => _events = {});
      return;
    }

    /// 🧩 2. get food items only from those fridges
    final foodSnapshot = await FirebaseFirestore.instance
        .collection('food_items')
        .where('fridgeId', whereIn: fridgeIds)
        .get();

    final Map<DateTime, List<FoodItem>> grouped = {};

    for (var doc in foodSnapshot.docs) {
      final data = doc.data();

      final item = FoodItem(
        id: doc.id,
        name: data['name'] ?? '',
        fridgeId: data['fridgeId'] ?? '',
        expirationDate: data['expirationDate'] != null
            ? (data['expirationDate'] as Timestamp).toDate()
            : null,
      );

      if (item.expirationDate == null) continue;

      final day = _normalize(item.expirationDate!);

      grouped.putIfAbsent(day, () => []);
      grouped[day]!.add(item);
    }

    setState(() {
      _events = grouped;
    });
  }

  List<FoodItem> _getEventsForDay(DateTime day) {
    return _events[_normalize(day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// 📅 CALENDAR
        TableCalendar<FoodItem>(
          firstDay: DateTime(2020),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,

          selectedDayPredicate: (day) =>
              isSameDay(_selectedDay, day),

          eventLoader: _getEventsForDay,

          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },

          calendarStyle: const CalendarStyle(
            markerDecoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),

        const SizedBox(height: 8),

        /// 📋 LISTE DES ALIMENTS DU JOUR
        Expanded(
          child: Builder(
            builder: (context) {
              final selected = _selectedDay ?? _focusedDay;
              final foods = _getEventsForDay(selected);

              if (foods.isEmpty) {
                return const Center(
                  child: Text("Aucun aliment pour ce jour"),
                );
              }

              return ListView.builder(
                itemCount: foods.length,
                itemBuilder: (context, index) {
                  final item = foods[index];

                  final daysLeft = item.expirationDate!
                      .difference(DateTime.now())
                      .inDays;

                  Color color;
                  if (daysLeft < 0) {
                    color = Colors.red;
                  } else if (daysLeft <= 2) {
                    color = Colors.orange;
                  } else {
                    color = Colors.green;
                  }

                  return ListTile(
                    leading: Icon(Icons.fastfood, color: color),
                    title: Text(item.name),
                    subtitle: Text(
                      "Expire le ${item.expirationDate!.day}/${item.expirationDate!.month}/${item.expirationDate!.year}",
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
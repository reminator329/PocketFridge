import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

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
  Map<String, String> _fridgeNames = {};

  static const String _prefsKey = 'selected_fridge_ids';

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadFoods() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    // 1. Récupère tous les frigos accessibles
    final fridgeSnapshot = await FirebaseFirestore.instance
        .collection('fridge_users')
        .where('userId', isEqualTo: userId)
        .get();

    final allFridgeIds = fridgeSnapshot.docs
        .map((d) => d['fridgeId'] as String)
        .toList();

    if (allFridgeIds.isEmpty) {
      setState(() => _events = {});
      return;
    }

    // 2. Filtre selon la sélection dans SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey);
    final fridgeIds = (saved == null || saved.isEmpty)
        ? allFridgeIds
        : saved.where((id) => allFridgeIds.contains(id)).toList();

    if (fridgeIds.isEmpty) {
      setState(() => _events = {});
      return;
    }

    // 3. Charge les noms des frigos
    final fridgesSnapshot = await FirebaseFirestore.instance
        .collection('fridges')
        .where('id', whereIn: fridgeIds)
        .get();

    final fridgeNames = {
      for (var doc in fridgesSnapshot.docs)
        doc['id'] as String: doc['name'] as String
    };

    // 4. Récupère les aliments des frigos sélectionnés
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
      _fridgeNames = fridgeNames;
    });
  }

  List<FoodItem> _getEventsForDay(DateTime day) {
    return _events[_normalize(day)] ?? [];
  }

  Color _expirationColor(DateTime expiration) {
    final daysLeft = expiration.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return Colors.red;
    if (daysLeft <= 2) return Colors.orange;
    return Colors.green;
  }

  String _expirationLabel(DateTime expiration) {
    final daysLeft = expiration.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return "Périmé !";
    if (daysLeft == 0) return "Expire aujourd'hui";
    if (daysLeft == 1) return "Expire demain";
    return "Dans $daysLeft jours";
  }

  Widget _buildCard(FoodItem item, ThemeData theme) {
    final color = _expirationColor(item.expirationDate!);
    final label = _expirationLabel(item.expirationDate!);
    final exp = item.expirationDate!;
    final fridgeName = _fridgeNames[item.fridgeId] ?? '';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withOpacity(0.4), width: 2),
      ),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fastfood, color: color, size: 32),
            ),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "${exp.day.toString().padLeft(2, '0')}/"
                  "${exp.month.toString().padLeft(2, '0')}/"
                  "${exp.year}",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            if (fridgeName.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.kitchen,
                      size: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      fridgeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        TableCalendar<FoodItem>(
          firstDay: DateTime(2020),
          lastDay: DateTime(2100),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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

        const Divider(),

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

              return SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: foods.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) =>
                      _buildCard(foods[index], theme),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
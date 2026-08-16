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

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey);
    final fridgeIds = (saved == null || saved.isEmpty)
        ? allFridgeIds
        : saved.where((id) => allFridgeIds.contains(id)).toList();

    if (fridgeIds.isEmpty) {
      setState(() => _events = {});
      return;
    }

    final fridgesSnapshot = await FirebaseFirestore.instance
        .collection('fridges')
        .where('id', whereIn: fridgeIds)
        .get();

    final fridgeNames = {
      for (var doc in fridgesSnapshot.docs)
        doc['id'] as String: doc['name'] as String
    };

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

  Future<void> _deleteItem(FoodItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer"),
        content: Text("Supprimer \"${item.name}\" ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('food_items')
        .doc(item.id)
        .delete();

    _loadFoods();
  }

  Future<void> _editItem(FoodItem item) async {
    final nameController = TextEditingController(text: item.name);
    DateTime? selectedDate = item.expirationDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Modifier l'aliment"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Nom"),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedDate == null
                          ? "Aucune date"
                          : "Expire le ${selectedDate!.day.toString().padLeft(2, '0')}/"
                          "${selectedDate!.month.toString().padLeft(2, '0')}/"
                          "${selectedDate!.year}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text("Changer"),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('food_items')
                    .doc(item.id)
                    .update({
                  'name': nameController.text.trim(),
                  if (selectedDate != null)
                    'expirationDate': Timestamp.fromDate(selectedDate!),
                });
                Navigator.pop(context);
                _loadFoods();
              },
              child: const Text("Enregistrer"),
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

              return ListView.builder(
                itemCount: foods.length,
                itemBuilder: (context, index) {
                  final item = foods[index];
                  final color = _expirationColor(item.expirationDate!);
                  final fridgeName = _fridgeNames[item.fridgeId] ?? '';

                  return ListTile(
                    leading: Icon(Icons.fastfood, color: color),
                    title: Text(item.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Expire le ${item.expirationDate!.day.toString().padLeft(2, '0')}/"
                              "${item.expirationDate!.month.toString().padLeft(2, '0')}/"
                              "${item.expirationDate!.year}",
                        ),
                        if (fridgeName.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.kitchen,
                                  size: 11,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4)),
                              const SizedBox(width: 4),
                              Text(
                                fridgeName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          color: theme.colorScheme.primary,
                          onPressed: () => _editItem(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red,
                          onPressed: () => _deleteItem(item),
                        ),
                      ],
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
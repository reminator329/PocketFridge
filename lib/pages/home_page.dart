import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/datamodel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FoodItem> _urgentFoods = [];
  List<FoodItem> _freshFoods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final fridgeSnapshot = await FirebaseFirestore.instance
        .collection('fridge_users')
        .where('userId', isEqualTo: userId)
        .get();

    final fridgeIds = fridgeSnapshot.docs
        .map((d) => d['fridgeId'] as String)
        .toList();

    if (fridgeIds.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final foodSnapshot = await FirebaseFirestore.instance
        .collection('food_items')
        .where('fridgeId', whereIn: fridgeIds)
        .get();

    final items = foodSnapshot.docs
        .map((doc) {
      final data = doc.data();
      return FoodItem(
        id: doc.id,
        name: data['name'] ?? '',
        fridgeId: data['fridgeId'] ?? '',
        expirationDate: data['expirationDate'] != null
            ? (data['expirationDate'] as Timestamp).toDate()
            : null,
      );
    })
        .where((item) => item.expirationDate != null)
        .toList()
      ..sort((a, b) => a.expirationDate!.compareTo(b.expirationDate!));

    setState(() {
      _urgentFoods = items.where((item) {
        final daysLeft = item.expirationDate!.difference(DateTime.now()).inDays;
        return daysLeft <= 2;
      }).toList();

      _freshFoods = items.where((item) {
        final daysLeft = item.expirationDate!.difference(DateTime.now()).inDays;
        return daysLeft > 2;
      }).toList();

      _loading = false;
    });
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

  Widget _buildHorizontalList(List<FoodItem> foods, ThemeData theme) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: foods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) => _buildCard(foods[index], theme),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Color titleColor,
    required List<FoodItem> foods,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
        ),
        _buildHorizontalList(foods, theme),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = _urgentFoods.isEmpty && _freshFoods.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Text(
            "Mon frigo",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.green),
                  const SizedBox(height: 12),
                  Text("Tout est frais ! 🎉",
                      style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_urgentFoods.isNotEmpty) ...[
                    _buildSection(
                      title: "⚠️ À consommer rapidement",
                      titleColor: Colors.orange.shade800,
                      foods: _urgentFoods,
                      theme: theme,
                    ),
                    const SizedBox(height: 28),
                  ],
                  if (_freshFoods.isNotEmpty)
                    _buildSection(
                      title: "✅ Encore frais",
                      titleColor: Colors.green.shade700,
                      foods: _freshFoods,
                      theme: theme,
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
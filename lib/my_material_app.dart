import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:pocket_fridge/pages/calendar_page.dart';
import 'package:pocket_fridge/pages/fridge_page.dart';
import 'package:pocket_fridge/pages/user_page.dart';

import 'forms/CreateObjectForm.dart';
import 'model/datamodel.dart';
import 'pages/home_page.dart';
import 'pages/product_scanner_page.dart';

class MyMaterialPage extends StatefulWidget {
  const MyMaterialPage({super.key});

  @override
  State<MyMaterialPage> createState() => _MyMaterialPageState();
}

class _MyMaterialPageState extends State<MyMaterialPage> {
  int _currentIndex = 0;

  Future<void> _openScanner({String? fridgeId}) async {
    final result = await Navigator.push<ScannedItemResult>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductScannerPage(targetFridgeId: fridgeId),
      ),
    );

    if (!mounted || result == null) return;

    showDialog(
      context: context,
      builder: (context) => CreateObjectForm(
        objectInstance: FoodItem(
          id: "",
          name: result.name ?? "",
          fridgeId: fridgeId ?? "",
          expirationDate: result.expirationDate,
        ),
      ),
    );
  }

  void _showAddFoodDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateObjectForm(
        objectInstance: FoodItem(
          id: "",
          name: "",
          fridgeId: "", // le formulaire gère la sélection du frigo
          expirationDate: null,
        ),
      ),
    );
  }

  void _showAddFridgeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateObjectForm(
        objectInstance: Fridge(id: "", name: ""),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData selectedIcon, String label) {
    final selected = _currentIndex == index;
    final color = Theme.of(context).colorScheme.primary;

    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: () => setState(() => _currentIndex = index),
        icon: Icon(selected ? selectedIcon : icon),
        color: selected ? color : null,
        iconSize: 26,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final backgroundAppBar = theme.colorScheme.secondaryContainer;
    final colorAppBar = theme.colorScheme.secondary;
    final backgroundScaffold = theme.colorScheme.surface;

    Widget page;
    switch (_currentIndex) {
      case 0:
        page = HomePage();
        break;
      case 1:
        page = CalendarPage();
        break;
      case 2:
        page = FridgePage();
        break;
      case 3:
        page = UserPage();
        break;
      default:
        throw UnimplementedError('no widget for $_currentIndex');
    }

    return Scaffold(
      backgroundColor: backgroundScaffold,
      body: page,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: backgroundAppBar,
        title: Text(
          "Pocket Fridge",
          style: TextStyle(color: colorAppBar),
        ),
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        shape: const CircleBorder(),
        spacing: 12,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.qr_code_scanner),
            label: "Scanner un aliment (Caméra)",
            onTap: () => _openScanner(),
          ),
          SpeedDialChild(
            child: const Icon(Icons.fastfood),
            label: "Nouvel aliment (Manuel)",
            onTap: () => _showAddFoodDialog(context),
          ),
          SpeedDialChild(
            child: const Icon(Icons.kitchen),
            label: "Nouveau frigo",
            onTap: () => _showAddFridgeDialog(context),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 56,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_outlined, Icons.home, "Accueil"),
            _buildNavItem(1, Icons.calendar_month_outlined,
                Icons.calendar_month, "Calendrier"),
            const SizedBox(width: 56),
            _buildNavItem(2, Icons.kitchen_outlined, Icons.kitchen, "Frigos"),
            _buildNavItem(3, Icons.account_circle_outlined,
                Icons.account_circle, "Compte"),
          ],
        ),
      ),
    );
  }
}
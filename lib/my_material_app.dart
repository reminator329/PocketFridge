
import 'package:flutter/material.dart';
import 'package:pocket_fridge/pages/calendar_page.dart';
import 'package:pocket_fridge/pages/create_page.dart';
import 'package:pocket_fridge/pages/fridge_page.dart';
import 'package:pocket_fridge/pages/user_page.dart';

import 'pages/home_page.dart';



class MyMaterialPage extends StatefulWidget {
  const MyMaterialPage({super.key});

  @override
  State<MyMaterialPage> createState() => _MyMaterialPageState();
}

class _MyMaterialPageState extends State<MyMaterialPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: "Accueil",
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: "Calendrier",
          ),
          NavigationDestination(
            icon: Icon(Icons.snowing),
            selectedIcon: Icon(Icons.snowing),
            label: "Frigos",
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: "Compte",
          ),
        ],
      ),
    );
  }
}
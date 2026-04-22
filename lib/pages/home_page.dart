import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    
    return Center(
      child: Column(
        children: [
          Text("Bienvenue dans ton frigo de poche !",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              color: theme.colorScheme.primary,
              // decoration: TextDecoration.underline
            ),
          ),
        ],
      ),
    );
  }
}

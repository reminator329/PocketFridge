import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserPage extends StatelessWidget {
  const UserPage({super.key});

  void logout() async {
    await FirebaseAuth.instance.signOut();
  }

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (currentUser != null && currentUser!.photoURL != null)
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(currentUser!.photoURL ?? ""),
              ),
            Text("Profil"),
            Text("Nom: ${currentUser!.displayName ?? "Aucun nom"}"),
            Text("Email: ${currentUser!.email ?? "Aucun email"}"),
            Text("UID: ${currentUser!.uid}"),
            Text("Email vérifié: ${currentUser!.emailVerified ? "Oui" : "Non"}"),
            ElevatedButton(onPressed: logout, child: Text("Déconnexion"))
          ]
        ),
      ),
    );
  }
}

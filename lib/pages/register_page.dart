import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterState();
}

class _RegisterState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final emailTextController = TextEditingController();
  final passwordTextController = TextEditingController();
  final confirmPasswordTextController = TextEditingController();

  void register() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailTextController.text,
        password: passwordTextController.text,
      );

      await FirebaseAuth.instance.currentUser!.sendEmailVerification();
      createUserIfNotExists(FirebaseAuth.instance.currentUser!);
      await migrateEmailToUserId();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Inscription validée")));
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        "email-already-in-use" => "L'adresse email est déjà utilisée",
        "invalid-email" => "L'adresse email est invalide",
        "weak-password" => "Le mot de passe est trop faible",
        _ => "Une erreur est survenue ${e.code}",
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    final backgroundScaffold = theme.colorScheme.primaryContainer;
    final backgroundAppBar = theme.colorScheme.primary;
    final colorAppBar = theme.colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: backgroundScaffold,
      appBar: AppBar(
        title: Text("S'inscrire", style: TextStyle(color: colorAppBar),), backgroundColor: backgroundAppBar,
      ),
      body: Center(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: emailTextController,
                decoration: InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: passwordTextController,
                decoration: InputDecoration(labelText: "Mot de passe"),
                obscureText: true,
              ),
              TextFormField(
                controller: confirmPasswordTextController,
                decoration: InputDecoration(
                  labelText: "Confirmer le mot de passe",
                ),
                obscureText: true,
              ),
              ElevatedButton(onPressed: register, child: Text("S'inscrire")),
            ],
          ),
        ),
      ),
    );
  }
}

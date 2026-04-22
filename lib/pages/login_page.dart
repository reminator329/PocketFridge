import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:pocket_fridge/model/datamodel.dart';
import 'package:pocket_fridge/pages/register_page.dart';
import 'package:sign_in_button/sign_in_button.dart';

import '../notification_service.dart';

Future<void> migrateEmailToUserId() async {
  final user = FirebaseAuth.instance.currentUser;


  if (user == null || user.email == null) return;
  print("EMAIL ${user.email}");

  final email = user.email!;
  final uid = user.uid;

  final query = await FirebaseFirestore.instance
      .collection('fridge_users')
      .get();

  for (final doc in query.docs) {
    final data = doc.data();
    print("EMAILE " + data['userId'].toString().toLowerCase());
    print("EMAILE test " + email.toLowerCase());
    if (data['userId'].toString().toLowerCase() != email.toLowerCase()) continue;

    /// 🔥 éviter doublon si déjà lié
    final existing = await FirebaseFirestore.instance
        .collection('fridge_users')
        .where('userId', isEqualTo: uid)
        .where('fridgeId', isEqualTo: data['fridgeId'])
        .get();

    if (existing.docs.isEmpty) {
      /// ✅ créer version propre avec UID
      await FirebaseFirestore.instance.collection('fridge_users').add(
          FridgeUser(id: '', fridgeId: data['fridgeId'], userId: uid, role: 'member').toMap()
      );
    }

    /// 🧹 supprimer l'entrée email
    await doc.reference.delete();
  }
}

Future<void> createUserIfNotExists(User user) async {
  final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  // final token = await FirebaseMessaging.instance.getToken();

  final doc = await userRef.get();

  if (!doc.exists) {
    await userRef.set({
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      // 'fcmToken': token
    });
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final emailTextController = TextEditingController();
  final passwordTextController = TextEditingController();

  Future<void> ensureInitialized() async {
    return GoogleSignInPlatform.instance.init(const InitParameters());
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      if (kIsWeb) {
        // ---- Web ----
        final googleProvider = GoogleAuthProvider();
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithPopup(googleProvider);
        final firebaseUser = userCredential.user;

        if (firebaseUser != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connexion réussie avec Google (Web)'),
            ),
          );
        }
      } else {
        await ensureInitialized();

        final AuthenticationResults result = await GoogleSignInPlatform.instance
            .authenticate(const AuthenticateParameters());

        final String? idToken = result.authenticationTokens.idToken;
        if (idToken != null) {
          final OAuthCredential credential = GoogleAuthProvider.credential(
            idToken: idToken,
          );
          UserCredential userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          final firebaseUser = userCredential.user;
          if (firebaseUser != null) {
            await createUserIfNotExists(firebaseUser);
            await migrateEmailToUserId();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connexion réussie avec Google (Mobile/Desktop)'),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de récupération du token Google')),
          );
        }
      }


    } on GoogleSignInException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion Google : $e')),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur Firebase auth : $e')));
    }
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailTextController.text,
        password: passwordTextController.text,
      );

      final user = FirebaseAuth.instance.currentUser!;

      await createUserIfNotExists(user);

      await FirebaseAuth.instance.currentUser!.sendEmailVerification();
      await migrateEmailToUserId();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Connexion OK")));
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        "user-disabled" => "L'utilisateur est désactivé",
        "invalid-email" => "L'adresse email est invalide",
        "invalid-credential" => "Le mot de passe est incorrect",
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
        title: Text("Se connecter", style: TextStyle(color: colorAppBar)),
        backgroundColor: backgroundAppBar,
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
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: "Vous n'avez pas de compte ? "),
                    TextSpan(
                      text: "Inscrivez-vous",
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RegisterPage(),
                            ),
                          );
                        },
                    ),
                  ],
                ),
              ),
              ElevatedButton(onPressed: login, child: Text("Se connecter")),

              Text("Ou"),

              SignInButton(
                Buttons.google,
                onPressed: () => signInWithGoogle(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

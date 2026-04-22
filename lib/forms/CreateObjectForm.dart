import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/datamodel.dart';
import '../model/metamodel.dart';

class CreateObjectForm extends StatefulWidget {
  final FirestoreSerializable objectInstance;

  const CreateObjectForm({super.key, required this.objectInstance});

  @override
  State<CreateObjectForm> createState() => _CreateObjectFormState();
}

class _CreateObjectFormState extends State<CreateObjectForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};

  @override
  Widget build(BuildContext context) {
    final objectInstance = widget.objectInstance;

    final fields = objectInstance.buildFormFields(_formData);

    return AlertDialog(
      title: Text("Créer ${objectInstance.displayName}"),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: fields,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();

              // 🔥 Crée l'objet via le builder
              final newObject = objectInstance.fromMapFunction(_formData);

              final docObject = FirebaseFirestore.instance
                  .collection(objectInstance.collectionName).doc();
              newObject.id = docObject.id;

              await docObject.set(newObject.toMap());

              if (newObject is Fridge) {
                final userId = FirebaseAuth.instance.currentUser!.uid; // 🔥 à remplacer par FirebaseAuth

                final fridge_user = FridgeUser(id: '', fridgeId: newObject.id, userId: userId, role: 'owner');

                await FirebaseFirestore.instance
                    .collection('fridge_users')
                    .add(fridge_user.toMap());
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${objectInstance.displayName} créé avec succès")),
              );
            }
          },
          child: const Text("Créer"),
        ),
      ],
    );
  }
}
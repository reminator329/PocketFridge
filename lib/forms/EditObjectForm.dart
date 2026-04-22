import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/metamodel.dart';

class EditObjectForm extends StatefulWidget {
  final FirestoreSerializable objectInstance;

  const EditObjectForm({super.key, required this.objectInstance});

  @override
  State<EditObjectForm> createState() => _EditObjectFormState();
}

class _EditObjectFormState extends State<EditObjectForm> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _formData;

  @override
  void initState() {
    super.initState();
    _formData = Map<String, dynamic>.from(widget.objectInstance.toMap());
  }

  @override
  Widget build(BuildContext context) {
    final objectInstance = widget.objectInstance;
    final fields = objectInstance.buildFormFields(_formData);

    return AlertDialog(
      title: Text("Modifier ${objectInstance.displayName}"),
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

              // Met à jour Firestore
              await FirebaseFirestore.instance
                  .collection(objectInstance.collectionName)
                  .doc(objectInstance.id)
                  .update(_formData);

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${objectInstance.displayName} mis à jour")),
              );
            }
          },
          child: const Text("Enregistrer"),
        ),
      ],
    );
  }
}

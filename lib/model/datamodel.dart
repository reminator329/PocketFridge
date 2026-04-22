import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:date_field/date_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../forms/EditObjectForm.dart';
import 'metamodel.dart';

/// -------------------------
/// ExerciseType (ExerciseTemplate)
/// -------------------------
class FoodItem extends FirestoreSerializable<FoodItem> {
  String name;
  DateTime? expirationDate;
  String fridgeId;

  FoodItem({required super.id, required this.name, required this.fridgeId, this.expirationDate});

  FoodItem copyWith({String? id, String? name, fridgeId, DateTime? expirationDate}) =>
      FoodItem(
        id: id ?? this.id,
        name: name ?? this.name,
        fridgeId: fridgeId ?? this.fridgeId,
        expirationDate: expirationDate ?? this.expirationDate,
      );

  @override
  String get collectionName => 'food_items';

  @override
  String get displayName => "FoodItem";

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'fridgeId': fridgeId,
    'expirationDate': expirationDate == null
        ? null
        : Timestamp.fromDate(expirationDate!),
  };

  @override
  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] as String? ?? "",
      name: map['name'] as String? ?? "",
      fridgeId: map['fridgeId'] as String? ?? "",
      expirationDate: (map['expirationDate'] as Timestamp?)?.toDate(),
    );
  }

  @override
  List<Widget> buildFormFields(Map<String, dynamic> formData) {
    formData['fridgeId'] = fridgeId;
    return [
      TextFormField(
        initialValue: name,
        decoration: const InputDecoration(labelText: "Nom de l'aliment *"),
        onSaved: (v) => formData['name'] = v,
        validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
      ),

      DateTimeFormField(
        initialValue: expirationDate,
        decoration: const InputDecoration(
          labelText: 'Date de péremption *',
          suffixIcon: Icon(Icons.calendar_today),
        ),
        mode: DateTimeFieldPickerMode.date,
        // firstDate: DateTime.now().add(const Duration(days: 10)),
        // lastDate: DateTime.now().add(const Duration(days: 40)),
        // initialPickerDateTime: DateTime.now().add(const Duration(days: 20)),
        onChanged: (DateTime? date) {
          formData['expirationDate'] = Timestamp.fromDate(date!);
        },

        /// ✅ validation
        validator: (date) {
          if (date == null) return "Date requise";
          return null;
        },
      ),
    ];
  }

  @override
  Widget buildListTile(BuildContext context) {
    return ListTile(
      title: Text(name),
      // subtitle: Text("ID: $id"),
      subtitle: Text(
        "Date de péremption: ${DateFormat.yMd().format(expirationDate!)}",
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: "Modifier",
            icon: const Icon(Icons.edit, color: Colors.blueAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => EditObjectForm(objectInstance: this),
              );
            },
          ),
          IconButton(
            tooltip: "Supprimer",
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Supprimer"),
                  content: Text("Supprimer $name ?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Annuler"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Supprimer"),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await FirebaseFirestore.instance
                    .collection(collectionName)
                    .doc(id)
                    .delete();

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("$name supprimé")));
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  // TODO: implement fromMapFunction
  FoodItem Function(Map<String, dynamic>) get fromMapFunction =>
      (map) => FoodItem.fromMap(map);
}

class Fridge extends FirestoreSerializable<Fridge> {
  final String name;

  Fridge({required super.id, required this.name});

  factory Fridge.fromMap(Map<String, dynamic> map) {
    return Fridge(id: map['id'] ?? '', name: map['name'] ?? '');
  }

  @override
  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }

  @override
  List<Widget> buildFormFields(Map<String, dynamic> formData) {
    return [
      TextFormField(
        initialValue: name,
        decoration: const InputDecoration(labelText: "Nom du frigo *"),
        onSaved: (v) => formData['name'] = v,
        validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
      ),
    ];
  }

  @override
  Widget buildListTile(BuildContext context) {
    // TODO: implement buildListTile
    throw UnimplementedError();
  }

  @override
  // TODO: implement collectionName
  String get collectionName => "fridges";

  @override
  // TODO: implement displayName
  String get displayName => "Fridge";

  @override
  // TODO: implement fromMapFunction
  FirestoreSerializable<FirestoreSerializable> Function(Map<String, dynamic> p1)
  get fromMapFunction =>
      (map) => Fridge.fromMap(map);
}

class FridgeUser extends FirestoreSerializable<FridgeUser> {
  final String fridgeId;
  final String userId;
  final String role;

  FridgeUser({
    required super.id,
    required this.fridgeId,
    required this.userId,
    required this.role,
  });

  factory FridgeUser.fromMap(String id, Map<String, dynamic> map) {
    return FridgeUser(
      id: id,
      fridgeId: map['fridgeId'],
      userId: map['userId'],
      role: map['role'] ?? 'member',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'fridgeId': fridgeId,
      'userId': userId,
      'role': role
    };
  }

  @override
  List<Widget> buildFormFields(Map<String, dynamic> formData) {
    // TODO: implement buildFormFields
    throw UnimplementedError();
  }

  @override
  Widget buildListTile(BuildContext context) {
    // TODO: implement buildListTile
    throw UnimplementedError();
  }

  @override
  // TODO: implement collectionName
  String get collectionName => throw UnimplementedError();

  @override
  // TODO: implement displayName
  String get displayName => throw UnimplementedError();

  @override
  // TODO: implement fromMapFunction
  FirestoreSerializable<FirestoreSerializable> Function(Map<String, dynamic> p1)
  get fromMapFunction => throw UnimplementedError();
}

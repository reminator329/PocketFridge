import 'dart:convert';

import 'package:flutter/material.dart';

abstract class FirestoreSerializable<T extends FirestoreSerializable<T>> {

  String id;

  FirestoreSerializable({required this.id});

  /// Convertit un objet en Map (pour Firestore ou JSON)
  Map<String, dynamic> toMap();

  /// Chaque classe doit fournir un constructeur statique fromMap
  static T fromMap<T extends FirestoreSerializable<T>>(Map<String, dynamic> map) {
    throw UnimplementedError();
  }

  /// Helper pour les listes
  static List<T> fromList<T extends FirestoreSerializable<T>>(
      List<dynamic>? list, T Function(Map<String, dynamic>) creator) {
    if (list == null) return [];
    return list.map((e) => creator(Map<String, dynamic>.from(e))).toList();
  }


  /// 🧩 Nom de la collection Firestore (ex: "exercise_types")
  String get collectionName;

  /// 🧱 Constructeur de l’objet depuis une Map
  FirestoreSerializable Function(Map<String, dynamic>) get fromMapFunction;

  /// 🖼️ Comment afficher un élément de la liste
  Widget buildListTile(BuildContext context);

  /// 🧰 Champs du formulaire
  List<Widget> buildFormFields(Map<String, dynamic> formData);

  /// 🏷️ Nom lisible pour l’utilisateur
  String get displayName;

  @override
  String toString() {
    return toMap().toString();
  }
}

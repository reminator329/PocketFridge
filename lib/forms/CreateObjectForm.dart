import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Pour FoodItem uniquement
  List<Fridge> _fridges = [];
  Fridge? _selectedFridge;
  bool _loadingFridges = false;

  static const String _lastFridgeKey = 'last_used_fridge_id';
  static const String _prefsKey = 'selected_fridge_ids';

  @override
  void initState() {
    super.initState();
    if (widget.objectInstance is FoodItem) {
      _loadFridges();
    }
  }

  Future<void> _loadFridges() async {
    setState(() => _loadingFridges = true);

    final userId = FirebaseAuth.instance.currentUser!.uid;

    final fridgeUsersSnap = await FirebaseFirestore.instance
        .collection('fridge_users')
        .where('userId', isEqualTo: userId)
        .get();

    final allFridgeIds = fridgeUsersSnap.docs
        .map((d) => d['fridgeId'] as String)
        .toList();

    if (allFridgeIds.isEmpty) {
      setState(() => _loadingFridges = false);
      return;
    }

    // Filtre selon sélection
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey);
    final fridgeIds = (saved == null || saved.isEmpty)
        ? allFridgeIds
        : saved.where((id) => allFridgeIds.contains(id)).toList();

    final fridgesSnap = await FirebaseFirestore.instance
        .collection('fridges')
        .where('id', whereIn: fridgeIds)
        .get();

    final fridges = fridgesSnap.docs
        .map((doc) => Fridge.fromMap(doc.data()))
        .toList();

    // Détermine le frigo pré-sélectionné :
    // 1. celui passé en paramètre (si non vide)
    // 2. le dernier utilisé (SharedPreferences)
    // 3. le premier de la liste
    final item = widget.objectInstance as FoodItem;
    final lastFridgeId = prefs.getString(_lastFridgeKey);

    Fridge? preselected;
    if (item.fridgeId.isNotEmpty) {
      preselected = fridges.firstWhere(
            (f) => f.id == item.fridgeId,
        orElse: () => fridges.first,
      );
    } else if (lastFridgeId != null) {
      preselected = fridges.firstWhere(
            (f) => f.id == lastFridgeId,
        orElse: () => fridges.first,
      );
    } else {
      preselected = fridges.isNotEmpty ? fridges.first : null;
    }

    setState(() {
      _fridges = fridges;
      _selectedFridge = preselected;
      if (preselected != null) {
        _formData['fridgeId'] = preselected.id;
      }
      _loadingFridges = false;
    });
  }

  Future<void> _saveLastFridge(String fridgeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastFridgeKey, fridgeId);
  }

  void _showFridgePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choisir un frigo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _fridges.map((fridge) {
            final isSelected = fridge.id == _selectedFridge?.id;
            return ListTile(
              leading: Icon(
                Icons.kitchen,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(fridge.name),
              trailing: isSelected
                  ? Icon(Icons.check,
                  color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                setState(() {
                  _selectedFridge = fridge;
                  _formData['fridgeId'] = fridge.id;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final objectInstance = widget.objectInstance;
    final isFoodItem = objectInstance is FoodItem;
    final fields = objectInstance.buildFormFields(_formData);

    return AlertDialog(
      title: Text("Créer ${objectInstance.displayName}"),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sélecteur de frigo uniquement pour FoodItem
            if (isFoodItem) ...[
              if (_loadingFridges)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                )
              else
                InkWell(
                  onTap: _fridges.length > 1 ? _showFridgePicker : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.kitchen,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedFridge?.name ?? "Aucun frigo",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_fridges.length > 1)
                          Icon(Icons.edit_outlined,
                              size: 16,
                              color:
                              theme.colorScheme.onSurface.withOpacity(0.4)),
                      ],
                    ),
                  ),
                ),
              const Divider(),
            ],
            ...fields,
          ],
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

              final newObject = objectInstance.fromMapFunction(_formData);

              final docObject = FirebaseFirestore.instance
                  .collection(objectInstance.collectionName)
                  .doc();
              newObject.id = docObject.id;

              await docObject.set(newObject.toMap());

              if (newObject is Fridge) {
                final userId = FirebaseAuth.instance.currentUser!.uid;
                final fridgeUser = FridgeUser(
                    id: '', fridgeId: newObject.id, userId: userId, role: 'owner');
                await FirebaseFirestore.instance
                    .collection('fridge_users')
                    .add(fridgeUser.toMap());
              }

              // Mémorise le dernier frigo utilisé
              if (newObject is FoodItem && _selectedFridge != null) {
                await _saveLastFridge(_selectedFridge!.id);
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        "${objectInstance.displayName} créé avec succès")),
              );
            }
          },
          child: const Text("Créer"),
        ),
      ],
    );
  }
}
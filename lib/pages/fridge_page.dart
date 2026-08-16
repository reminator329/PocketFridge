import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../forms/CreateObjectForm.dart';
import '../model/datamodel.dart';

void _showShareDialog(BuildContext context, String fridgeId) {
  final emailController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Partager le frigo"),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: "Email de l'utilisateur",
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return "Email requis";
              if (!value.contains('@')) return "Email invalide";
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final email = emailController.text.trim();
              await FirebaseFirestore.instance
                  .collection('fridge_users')
                  .add(FridgeUser(
                id: '',
                fridgeId: fridgeId,
                userId: email,
                role: 'member',
              ).toMap());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Invitation envoyée")),
              );
            },
            child: const Text("Partager"),
          ),
        ],
      );
    },
  );
}

Future<void> _deleteItem(BuildContext context, FoodItem item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Supprimer"),
      content: Text("Supprimer \"${item.name}\" ?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Supprimer"),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  await FirebaseFirestore.instance
      .collection('food_items')
      .doc(item.id)
      .delete();
}

Future<void> _editItem(BuildContext context, FoodItem item) async {
  final nameController = TextEditingController(text: item.name);
  DateTime? selectedDate = item.expirationDate;

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text("Modifier l'aliment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nom"),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDate == null
                        ? "Aucune date"
                        : "Expire le ${selectedDate!.day.toString().padLeft(2, '0')}/"
                        "${selectedDate!.month.toString().padLeft(2, '0')}/"
                        "${selectedDate!.year}",
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text("Changer"),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('food_items')
                  .doc(item.id)
                  .update({
                'name': nameController.text.trim(),
                if (selectedDate != null)
                  'expirationDate': Timestamp.fromDate(selectedDate!),
              });
              Navigator.pop(context);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    ),
  );
}

class _FridgeItemsList extends StatelessWidget {
  final String fridgeId;

  const _FridgeItemsList({required this.fridgeId});

  Color _expirationColor(DateTime expiration) {
    final daysLeft = expiration.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return Colors.red;
    if (daysLeft <= 2) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('food_items')
          .where('fridgeId', isEqualTo: fridgeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text("Erreur ${snapshot.error}");
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final items = snapshot.data!.docs.map((doc) {
          final data = doc.data();
          return FoodItem(
            id: doc.id,
            name: data['name'] ?? '',
            fridgeId: data['fridgeId'] ?? '',
            expirationDate: data['expirationDate'] != null
                ? (data['expirationDate'] as Timestamp).toDate()
                : null,
          );
        }).toList();

        if (items.isEmpty) return const Padding(
          padding: EdgeInsets.all(12),
          child: Text("Aucun aliment"),
        );

        return Column(
          children: [
            for (final item in items) ...[
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.fastfood,
                  color: item.expirationDate != null
                      ? _expirationColor(item.expirationDate!)
                      : Colors.grey,
                ),
                title: Text(item.name),
                subtitle: item.expirationDate != null
                    ? Text(
                  "Expire le ${item.expirationDate!.day.toString().padLeft(2, '0')}/"
                      "${item.expirationDate!.month.toString().padLeft(2, '0')}/"
                      "${item.expirationDate!.year}",
                )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      color: theme.colorScheme.primary,
                      onPressed: () => _editItem(context, item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                      onPressed: () => _deleteItem(context, item),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class FridgePage extends StatefulWidget {
  const FridgePage({super.key});

  @override
  State<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends State<FridgePage> {
  int? expandedIndex;
  Set<String> _selectedFridgeIds = {};
  bool _selectionInitialized = false;

  static const String _prefsKey = 'selected_fridge_ids';

  Future<void> _initSelectionIfNeeded(List<String> allFridgeIds) async {
    if (_selectionInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey);
    setState(() {
      _selectedFridgeIds = (saved ?? allFridgeIds).toSet();
      _selectionInitialized = true;
    });
  }

  Future<void> _toggleFridge(String fridgeId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_selectedFridgeIds.contains(fridgeId)) {
        _selectedFridgeIds.remove(fridgeId);
      } else {
        _selectedFridgeIds.add(fridgeId);
      }
    });
    await prefs.setStringList(_prefsKey, _selectedFridgeIds.toList());
  }

  void _showCreateFridgeDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateObjectForm(
        objectInstance: Fridge(id: "", name: ""),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('fridge_users')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Erreur ${snapshot.error}');
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final fridgeIds = snapshot.data!.docs
            .map((doc) => doc['fridgeId'] as String)
            .toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initSelectionIfNeeded(fridgeIds);
        });

        final selectedCount = _selectedFridgeIds.length;
        final totalCount = fridgeIds.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bandeau info + bouton nouveau frigo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      totalCount == 0
                          ? "Aucun frigo"
                          : selectedCount == totalCount
                          ? "Tous les frigos sont affichés"
                          : "$selectedCount / $totalCount frigo(s) sélectionné(s)",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showCreateFridgeDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Nouveau frigo"),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Liste des frigos
            if (fridgeIds.isEmpty)
              const Expanded(child: Center(child: Text("Aucun frigo")))
            else
              Expanded(
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('fridges')
                      .where('id', whereIn: fridgeIds)
                      .snapshots(),
                  builder: (context, fridgeSnapshot) {
                    if (!fridgeSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final fridges = fridgeSnapshot.data!.docs;

                    return ListView.builder(
                      itemCount: fridges.length,
                      itemBuilder: (context, index) {
                        final fridge = Fridge.fromMap(fridges[index].data());
                        final isExpanded = expandedIndex == index;
                        final isSelected =
                        _selectedFridgeIds.contains(fridge.id);

                        return Card(
                          elevation: 6,
                          child: Column(
                            children: [
                              CheckboxListTile(
                                controlAffinity:
                                ListTileControlAffinity.leading,
                                value: isSelected,
                                onChanged: (_) => _toggleFridge(fridge.id),
                                title: Text(
                                  fridge.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? null
                                        : theme.colorScheme.onSurface
                                        .withOpacity(0.4),
                                  ),
                                ),
                                subtitle: Text(
                                  isSelected
                                      ? "Affiché dans les autres onglets"
                                      : "Masqué dans les autres onglets",
                                  style: TextStyle(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface
                                        .withOpacity(0.4),
                                    fontSize: 12,
                                  ),
                                ),
                                secondary: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // + Aliment directement dans la carte
                                    IconButton(
                                      tooltip: "Ajouter un aliment",
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) =>
                                              CreateObjectForm(
                                                objectInstance: FoodItem(
                                                  id: "",
                                                  name: "",
                                                  fridgeId: fridge.id,
                                                  expirationDate: null,
                                                ),
                                              ),
                                        );
                                      },
                                      icon: const Icon(Icons.add),
                                    ),
                                    IconButton(
                                      tooltip: "Partager",
                                      onPressed: () =>
                                          _showShareDialog(context, fridge.id),
                                      icon: const Icon(Icons.share),
                                    ),
                                    IconButton(
                                      tooltip: isExpanded
                                          ? "Réduire"
                                          : "Voir les aliments",
                                      onPressed: () {
                                        setState(() {
                                          expandedIndex =
                                          isExpanded ? null : index;
                                        });
                                      },
                                      icon: Icon(isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more),
                                    ),
                                  ],
                                ),
                              ),
                              if (isExpanded)
                                Padding(
                                  padding:
                                  const EdgeInsets.only(bottom: 10),
                                  child:
                                  _FridgeItemsList(fridgeId: fridge.id),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
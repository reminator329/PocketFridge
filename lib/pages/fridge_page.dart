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
                  .add(
                    FridgeUser(
                      id: '',
                      fridgeId: fridgeId,
                      userId: email,
                      role: 'member',
                    ).toMap(),
                  );
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

class _FridgeItemsList extends StatelessWidget {
  final String fridgeId;

  const _FridgeItemsList({required this.fridgeId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('food_items')
          .where('fridgeId', isEqualTo: fridgeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text("Erreur ${snapshot.error}");
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final items = snapshot.data!.docs
            .map((doc) => FoodItem.fromMap(doc.data()))
            .toList();

        if (items.isEmpty) return const Text("Aucun aliment");

        return Column(
          children: [
            for (final item in items) ...[
              const Divider(),
              item.buildListTile(context),
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

  static Future<List<String>> loadSelectedFridgeIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey) ?? [];
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

        // Initialise la sélection avec tous les IDs si premier lancement
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initSelectionIfNeeded(fridgeIds);
        });

        final selectedCount = _selectedFridgeIds.length;
        final totalCount = fridgeIds.length;

        return Stack(
          children: [
            if (fridgeIds.isEmpty)
              const Center(child: Text("Aucun frigo"))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      selectedCount == totalCount
                          ? "Tous les frigos sont affichés dans les autres onglets"
                          : "$selectedCount / $totalCount frigo(s) sélectionné(s)",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder(
                      stream: FirebaseFirestore.instance
                          .collection('fridges')
                          .where('id', whereIn: fridgeIds)
                          .snapshots(),
                      builder: (context, fridgeSnapshot) {
                        if (!fridgeSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final fridges = fridgeSnapshot.data!.docs;

                        return ListView.builder(
                          itemCount: fridges.length,
                          itemBuilder: (context, index) {
                            final fridge = Fridge.fromMap(
                              fridges[index].data(),
                            );
                            final isExpanded = expandedIndex == index;
                            final isSelected = _selectedFridgeIds.contains(
                              fridge.id,
                            );

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
                                        IconButton(
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
                                          onPressed: () => _showShareDialog(
                                            context,
                                            fridge.id,
                                          ),
                                          icon: const Icon(Icons.share),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              expandedIndex = isExpanded
                                                  ? null
                                                  : index;
                                            });
                                          },
                                          icon: Icon(
                                            isExpanded
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isExpanded)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _FridgeItemsList(
                                        fridgeId: fridge.id,
                                      ),
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
              ),

            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => CreateObjectForm(
                      objectInstance: Fridge(id: "", name: ""),
                    ),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
}

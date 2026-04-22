import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
              if (value == null || value.isEmpty) {
                return "Email requis";
              }
              if (!value.contains('@')) {
                return "Email invalide";
              }
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

              /// 🔥 créer invitation
              await FirebaseFirestore.instance
                  .collection('fridge_users')
                  .add(FridgeUser(id: '', fridgeId: fridgeId, userId: email, role: 'member').toMap());

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
        if (snapshot.hasError) {
          return Text("Erreur ${snapshot.error}");
        }

        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final docs = snapshot.data!.docs;

        final items = docs.map((doc) {
          final data = doc.data();
          return FoodItem.fromMap(data);
        }).toList();

        if (items.isEmpty) {
          return const Text("Aucun aliment");
        }

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
  int? expandedIndex = 0;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    final backgroundCardColor = theme.colorScheme.secondaryContainer;
    final cardColor = theme.colorScheme.secondary;

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('fridge_users')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),

      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Erreur ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        /// 🧠 STEP 1: GET FRIDGE IDS
        final fridgeIds = snapshot.data!.docs
            .map((doc) => doc['fridgeId'] as String)
            .toList();
        return Stack(
          children: [
            if (fridgeIds.isEmpty)
              const Center(child: Text("Aucun frigo"))
            else
              StreamBuilder(
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
                      final fridgeDoc = fridges[index];

                      final fridge = Fridge.fromMap(fridgeDoc.data());

                      final isExpanded = expandedIndex == index;

                      return Card(
                        elevation: 6,
                        color: backgroundCardColor,
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(
                                fridge.name,
                                style: TextStyle(color: cardColor),
                              ),
                              subtitle: const Text("Frigo partagé"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => CreateObjectForm(
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


                                  /// 🔗 SHARE FRIDGE
                                  IconButton(
                                    onPressed: () {
                                      _showShareDialog(context, fridge.id);
                                    },
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
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _FridgeItemsList(fridgeId: fridge.id),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

            /// ➕ CREATE FRIDGE BUTTON (toujours visible)
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

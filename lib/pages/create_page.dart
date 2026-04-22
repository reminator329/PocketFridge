import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../forms/CreateObjectForm.dart';
import '../model/datamodel.dart';
import '../model/metamodel.dart';

class _FirestoreList extends StatelessWidget {
  final FirestoreSerializable instance;

  const _FirestoreList({required this.instance});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection(instance.collectionName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Erreur de chargement ${snapshot.error!}');
        }
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final docs = snapshot.data!.docs;
        final items = docs.map((doc) {
          final data = doc.data();
          return instance.fromMapFunction(data);
        }).toList();

        if (items.isEmpty) return const Text('Aucun élément');

        return Column(
          children: [
            for (var item in items) ...[
              const Divider(),
              item.buildListTile(context),
            ],
          ],
        );
      },
    );
  }
}

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  int? expandedIndex = 0;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    final backgroundCardColor = theme.colorScheme.secondaryContainer;
    final cardColor = theme.colorScheme.secondary;
    /*
    final List<FirestoreSerializable> formsCreateObject = [
      ExerciseType(name: ""),
      // Session(name: "", date: ""),
    ];

 */
    final List<FirestoreSerializable> emptyInstances = [
      FoodItem(id:"", name: "", fridgeId: "", expirationDate: null),
      /*
      FormCreateObject<Session>(
        label: "Séance",
        builder: (map) => Session.fromMap(map),
      ),

       */
    ];

    return ListView.builder(
      itemCount: emptyInstances.length,
      itemBuilder: (context, index) {
        final emptyInstance = emptyInstances[index];
        final displayName = emptyInstance.displayName;
        final isExpanded = expandedIndex == index;

        return Card(
          elevation: 6,
          color: backgroundCardColor,
          child: Column(
            children: [
              ListTile(
                title: Text(displayName, style: TextStyle(color: cardColor)),
                subtitle: Text(
                  "Créer un object $displayName en base de données",
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) =>
                              CreateObjectForm(objectInstance: emptyInstance),
                        );
                      },
                      icon: Icon(Icons.add),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          expandedIndex = isExpanded ? null : index;
                        });
                      },
                      icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                      ),
                    ),
                  ],
                ),
              ),

              // Liste Firestore si déplié
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FirestoreList(instance: emptyInstance),
                ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_fridge/widgets/scanner/detection_status_card.dart';

void main() {
  testWidgets('DetectionStatusCard affiche correctement les états de détection',
      (WidgetTester tester) async {
    bool confirmed = false;
    bool manualEntry = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetectionStatusCard(
            productName: "Lait demi-écrémé",
            isSearchingName: false,
            expirationDate: DateTime(2026, 12, 25),
            onConfirm: () => confirmed = true,
            onManualEntry: () => manualEntry = true,
          ),
        ),
      ),
    );

    // Vérifie la présence du nom du produit
    expect(find.text("Lait demi-écrémé"), findsOneWidget);

    // Vérifie le formatage de la date
    expect(find.text("25/12/2026"), findsOneWidget);

    // Vérifie le statut complet
    expect(find.text("Informations détectées !"), findsOneWidget);

    // Teste le tap sur le bouton Valider
    await tester.tap(find.text("Valider"));
    expect(confirmed, isTrue);
  });
}

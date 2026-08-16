import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_fridge/services/scanner/ocr_date_service.dart';

void main() {
  group('OcrDateService - Date Parsing Tests', () {
    test('Extrait format standard JJ/MM/AAAA', () {
      final text = "A CONSOMMER AVANT LE 25/12/2026 LOT A42";
      final date = OcrDateService.parseDateFromText(text);

      expect(date, isNotNull);
      expect(date!.day, equals(25));
      expect(date.month, equals(12));
      expect(date.year, equals(2026));
    });

    test('Extrait format avec points JJ.MM.AA', () {
      final text = "DLC: 14.05.27 EXP";
      final date = OcrDateService.parseDateFromText(text);

      expect(date, isNotNull);
      expect(date!.day, equals(14));
      expect(date.month, equals(5));
      expect(date.year, equals(2027));
    });

    test('Extrait format textuel JJ MMM AAAA', () {
      final text = "A CONSOMMER JUSQU'AU 18 AVR 2027";
      final date = OcrDateService.parseDateFromText(text);

      expect(date, isNotNull);
      expect(date!.day, equals(18));
      expect(date.month, equals(4)); // AVR = Avril = 4
      expect(date.year, equals(2027));
    });

    test('Extrait format mois/annee MM/AAAA', () {
      final text = "BEST BEFORE 11/2028";
      final date = OcrDateService.parseDateFromText(text);

      expect(date, isNotNull);
      expect(date!.month, equals(11));
      expect(date.year, equals(2028));
      expect(date.day, equals(30)); // Dernier jour de novembre
    });

    test('Ignore le texte sans date valide', () {
      final text = "YOP FRAISE 450G YOPLAIT FRANCE FABRIQUE EN NORMANDIE";
      final date = OcrDateService.parseDateFromText(text);

      expect(date, isNull);
    });
  });
}

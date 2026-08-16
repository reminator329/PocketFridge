import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service responsable de l'analyse OCR et de l'extraction de la date de péremption.
class OcrDateService {
  final TextRecognizer _recognizer;

  OcrDateService()
      : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Analyse une image ML Kit et tente d'en extraire une date de péremption valide.
  Future<DateTime?> processImage(InputImage inputImage) async {
    try {
      final RecognizedText recognizedText =
          await _recognizer.processImage(inputImage);
      if (recognizedText.text.trim().isNotEmpty) {
        final date = parseDateFromText(recognizedText.text);
        if (date != null) {
          debugPrint('[SCANNER] 📅 Date détectée: $date à partir du texte: "${recognizedText.text.replaceAll('\n', ' ')}"');
        }
        return date;
      }
    } catch (e) {
      debugPrint('[SCANNER] ⚠️ Erreur ML Kit OCR: $e');
    }
    return null;
  }

  /// Dictionnaire des mois textuels courants en français et anglais
  static const Map<String, int> _monthNames = {
    'jan': 1, 'janv': 1, 'janvier': 1, 'january': 1,
    'fev': 2, 'fevr': 2, 'fév': 2, 'févr': 2, 'fevrier': 2, 'février': 2, 'feb': 2, 'february': 2,
    'mar': 3, 'mars': 3, 'march': 3,
    'avr': 4, 'avril': 4, 'apr': 4, 'april': 4,
    'mai': 5, 'may': 5,
    'juin': 6, 'jun': 6, 'june': 6,
    'juil': 7, 'juill': 7, 'juillet': 7, 'jul': 7, 'july': 7,
    'aou': 8, 'aout': 8, 'août': 8, 'aug': 8, 'august': 8,
    'sep': 9, 'sept': 9, 'septembre': 9, 'september': 9,
    'oct': 10, 'octobre': 10, 'october': 10,
    'nov': 11, 'novembre': 11, 'november': 11,
    'dec': 12, 'dece': 12, 'déc': 12, 'décembre': 12, 'decembre': 12, 'december': 12,
  };

  /// Extrait une date de péremption à partir d'un bloc de texte brut.
  static DateTime? parseDateFromText(String rawText) {
    if (rawText.trim().isEmpty) return null;

    final text = rawText.toUpperCase();
    final now = DateTime.now();
    // On accepte les dates récentes (jusqu'à 30 jours dans le passé) et futures (jusqu'à 10 ans)
    final minDate = now.subtract(const Duration(days: 30));
    final maxDate = DateTime(now.year + 10, 12, 31);

    // 1. Format textuel : "15 AVR 2026", "12 DEC 26"
    final textMonthRegex = RegExp(
      r'\b(\d{1,2})\s+([A-ZÉÈÀ]{3,9})\s+(\d{2,4})\b',
      caseSensitive: false,
    );
    for (final match in textMonthRegex.allMatches(text)) {
      try {
        final day = int.parse(match.group(1)!);
        final monthStr = match.group(2)!.toLowerCase();
        final yearRaw = int.parse(match.group(3)!);
        final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;

        // Trouver le mois correspondant
        final monthEntry = _monthNames.entries.firstWhere(
          (entry) => monthStr.startsWith(entry.key),
          orElse: () => const MapEntry('', 0),
        );

        if (monthEntry.value > 0 && day >= 1 && day <= 31) {
          final candidate = DateTime(year, monthEntry.value, day);
          if (candidate.isAfter(minDate) && candidate.isBefore(maxDate)) {
            return candidate;
          }
        }
      } catch (_) {}
    }

    // 2. Format numérique standard : "15/08/2026", "15.08.26", "15-08-2026"
    final standardRegex = RegExp(
      r'\b(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})\b',
    );
    for (final match in standardRegex.allMatches(text)) {
      try {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final yearRaw = int.parse(match.group(3)!);
        final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;

        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          final candidate = DateTime(year, month, day);
          if (candidate.isAfter(minDate) && candidate.isBefore(maxDate)) {
            return candidate;
          }
        }
      } catch (_) {}
    }

    // 3. Format mois/année : "08/2026" ou "08/26"
    final monthYearRegex = RegExp(
      r'\b(\d{1,2})[\/\.\-](\d{2,4})\b',
    );
    for (final match in monthYearRegex.allMatches(text)) {
      try {
        final month = int.parse(match.group(1)!);
        final yearRaw = int.parse(match.group(2)!);
        final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;

        // On évite de confondre avec des fractions (ex: 1/2) en validant l'année
        if (month >= 1 && month <= 12 && year >= now.year && year <= now.year + 10) {
          // On place la date au dernier jour du mois
          final lastDay = DateTime(year, month + 1, 0).day;
          final candidate = DateTime(year, month, lastDay);
          if (candidate.isAfter(minDate) && candidate.isBefore(maxDate)) {
            return candidate;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Libère les ressources du TextRecognizer
  void dispose() {
    _recognizer.close();
  }
}

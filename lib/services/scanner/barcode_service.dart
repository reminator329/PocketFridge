import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Service responsable de la détection des codes-barres sur les images.
class BarcodeService {
  final BarcodeScanner _scanner;

  BarcodeService()
      : _scanner = BarcodeScanner(formats: [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upca,
          BarcodeFormat.upce,
          BarcodeFormat.code128,
          BarcodeFormat.qrCode,
        ]);

  /// Analyse une image ML Kit et retourne le premier code-barres valide détecté.
  Future<String?> processImage(InputImage inputImage) async {
    try {
      final List<Barcode> barcodes = await _scanner.processImage(inputImage);
      for (final barcode in barcodes) {
        final rawValue = barcode.rawValue;
        if (rawValue != null && rawValue.trim().isNotEmpty) {
          debugPrint('[SCANNER] 🎯 Code-barres détecté: $rawValue (${barcode.format})');
          return rawValue.trim();
        }
      }
    } catch (e) {
      debugPrint('[SCANNER] ⚠️ Erreur ML Kit Barcode: $e');
    }
    return null;
  }

  /// Libère les ressources du scanner ML Kit
  void dispose() {
    _scanner.close();
  }
}

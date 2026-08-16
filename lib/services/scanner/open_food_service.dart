import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Modèle simple pour les informations récupérées depuis Open Food Facts
class ScannedProductInfo {
  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;

  ScannedProductInfo({
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
  });

  /// Nom complet formaté (ex: "Nutella (Ferrero)" ou juste "Nutella")
  String get displayName {
    if (brand != null && brand!.isNotEmpty && !name.toLowerCase().contains(brand!.toLowerCase())) {
      return '$name ($brand)';
    }
    return name;
  }
}

/// Service permettant d'interroger la base de données Open Food Facts
class OpenFoodService {
  // Cache en mémoire pour éviter les requêtes répétées sur le même code-barres
  static final Map<String, ScannedProductInfo?> _cache = {};

  /// Récupère les détails d'un produit à partir de son code-barres (EAN-13, EAN-8, etc.)
  static Future<ScannedProductInfo?> fetchProduct(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    if (_cache.containsKey(cleanBarcode)) {
      return _cache[cleanBarcode];
    }

    try {
      debugPrint('[SCANNER] 🌐 Requête Open Food Facts pour code-barres: $cleanBarcode');
      final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$cleanBarcode.json?fields=product_name,product_name_fr,brands,image_front_small_url',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'PocketFridge - FlutterApp - Version 1.0',
        },
      ).timeout(const Duration(seconds: 5));

      debugPrint('[SCANNER] 🌐 Réponse API HTTP ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'];
          final nameFr = product['product_name_fr'] as String?;
          final nameDefault = product['product_name'] as String?;
          final name = (nameFr != null && nameFr.trim().isNotEmpty)
              ? nameFr.trim()
              : (nameDefault != null && nameDefault.trim().isNotEmpty)
                  ? nameDefault.trim()
                  : null;

          if (name != null && name.isNotEmpty) {
            final brand = product['brands'] as String?;
            final imageUrl = product['image_front_small_url'] as String?;

            final productInfo = ScannedProductInfo(
              barcode: cleanBarcode,
              name: name,
              brand: brand?.split(',').first.trim(),
              imageUrl: imageUrl,
            );

            debugPrint('[SCANNER] ✅ Produit identifié : ${productInfo.displayName}');
            _cache[cleanBarcode] = productInfo;
            return productInfo;
          }
        }
        debugPrint('[SCANNER] ℹ️ Produit non répertorié sur Open Food Facts pour le code: $cleanBarcode');
      }
    } catch (e) {
      debugPrint('[SCANNER] ❌ Erreur réseau Open Food Facts : $e');
    }

    _cache[cleanBarcode] = null;
    return null;
  }
}

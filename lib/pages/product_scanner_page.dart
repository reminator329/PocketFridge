import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/scanner/barcode_service.dart';
import '../services/scanner/camera_image_converter.dart';
import '../services/scanner/ocr_date_service.dart';
import '../services/scanner/open_food_service.dart';
import '../widgets/scanner/detection_status_card.dart';
import '../widgets/scanner/scanner_overlay.dart';

/// Résultat retourné par le scanner
class ScannedItemResult {
  final String? name;
  final DateTime? expirationDate;
  final String? barcode;

  ScannedItemResult({
    this.name,
    this.expirationDate,
    this.barcode,
  });
}

/// Page principale du scanner caméra pour aliments
class ProductScannerPage extends StatefulWidget {
  final String? targetFridgeId;

  const ProductScannerPage({super.key, this.targetFridgeId});

  @override
  State<ProductScannerPage> createState() => _ProductScannerPageState();
}

class _ProductScannerPageState extends State<ProductScannerPage>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isTorchOn = false;
  bool _isInitializing = true;
  String? _errorMessage;

  // Services ML Kit
  final BarcodeService _barcodeService = BarcodeService();
  final OcrDateService _ocrDateService = OcrDateService();

  // État de détection
  bool _isProcessingFrame = false;
  String? _detectedBarcode;
  String? _detectedProductName;
  bool _isSearchingName = false;
  DateTime? _detectedExpirationDate;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCameraStream();
    _cameraController?.dispose();
    _barcodeService.dispose();
    _ocrDateService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _stopCameraStream();
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  bool _isPermissionPermanentlyDenied = false;

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _isPermissionPermanentlyDenied = false;
    });

    try {
      // 1. Vérification et demande explicite de la permission caméra
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _errorMessage =
              "L'accès à la caméra est nécessaire pour scanner vos aliments.";
          _isPermissionPermanentlyDenied = status.isPermanentlyDenied;
          _isInitializing = false;
        });
        return;
      }

      // 2. Récupération des caméras disponibles
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = "Aucune caméra disponible sur cet appareil.";
          _isInitializing = false;
        });
        return;
      }

      // Par défaut, sélectionner la caméra arrière
      _selectedCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      await _setupCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur lors de l'initialisation de la caméra : $e";
        _isInitializing = false;
      });
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      // Démarrage du flux d'analyse d'images
      await controller.startImageStream(_processCameraFrame);

      setState(() {
        _isInitializing = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Impossible de démarrer le flux vidéo : $e";
        _isInitializing = false;
      });
    }
  }

  Future<void> _stopCameraStream() async {
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.stopImageStream();
      } catch (_) {}
    }
  }

  int _debugFrameCount = 0;

  /// Traite chaque frame de la caméra avec Throttling pour éviter de saturer le CPU
  void _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || _isCompleted) return;
    _isProcessingFrame = true;
    _debugFrameCount++;

    if (_debugFrameCount % 30 == 1) {
      debugPrint(
        '[SCANNER] 📸 Frame #$_debugFrameCount (${image.width}x${image.height}, format: ${image.format.raw}, planes: ${image.planes.length})',
      );
    }

    try {
      final camera = _cameras[_selectedCameraIndex];
      final inputImage = CameraImageConverter.convertToInputImage(
        image: image,
        camera: camera,
      );

      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      // 1. Recherche du code-barres (si pas encore trouvé)
      if (_detectedProductName == null && !_isSearchingName) {
        final barcode = await _barcodeService.processImage(inputImage);
        if (barcode != null && barcode != _detectedBarcode) {
          _detectedBarcode = barcode;
          _fetchProductName(barcode);
        }
      }

      // 2. Recherche de la date d'expiration via OCR (si pas encore trouvée)
      if (_detectedExpirationDate == null) {
        final date = await _ocrDateService.processImage(inputImage);
        if (date != null && mounted) {
          setState(() {
            _detectedExpirationDate = date;
          });
          _checkIfComplete();
        }
      }
    } catch (e, stack) {
      debugPrint('[SCANNER] ❌ Erreur analyse frame: $e\n$stack');
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Récupère le nom du produit auprès d'Open Food Facts
  Future<void> _fetchProductName(String barcode) async {
    if (!mounted) return;
    setState(() => _isSearchingName = true);

    final info = await OpenFoodService.fetchProduct(barcode);

    if (!mounted) return;
    setState(() {
      _isSearchingName = false;
      if (info != null) {
        _detectedProductName = info.displayName;
      }
    });

    _checkIfComplete();
  }

  /// Vérifie si les deux informations sont trouvées pour valider automatiquement
  void _checkIfComplete() {
    if (_detectedProductName != null &&
        _detectedExpirationDate != null &&
        !_isCompleted) {
      _isCompleted = true;
      // Retour haptique (vibration)
      HapticFeedback.mediumImpact();
      _finishScanning();
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      if (_isTorchOn) {
        await controller.setFlashMode(FlashMode.off);
        setState(() => _isTorchOn = false);
      } else {
        await controller.setFlashMode(FlashMode.torch);
        setState(() => _isTorchOn = true);
      }
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    await _stopCameraStream();
    await _cameraController?.dispose();

    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      _isInitializing = true;
    });

    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  void _finishScanning() async {
    await _stopCameraStream();
    if (!mounted) return;

    Navigator.pop(
      context,
      ScannedItemResult(
        name: _detectedProductName,
        expirationDate: _detectedExpirationDate,
        barcode: _detectedBarcode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Définition de la fenêtre de visée centrale
    const scanWindowWidth = 280.0;
    const scanWindowHeight = 280.0;
    final scanWindow = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.40),
      width: scanWindowWidth,
      height: scanWindowHeight,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Vue Caméra
          if (_cameraController != null &&
              _cameraController!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_rounded,
                        color: Colors.amber, size: 54),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isPermissionPermanentlyDenied)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.settings),
                        onPressed: openAppSettings,
                        label: const Text("Ouvrir les paramètres"),
                      )
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        onPressed: _initializeCamera,
                        label: const Text("Autoriser / Réessayer"),
                      ),
                  ],
                ),
              ),
            )
          else if (_isInitializing)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // 2. Overlay avec Viseur animé
          if (_cameraController != null &&
              _cameraController!.value.isInitialized)
            Positioned.fill(
              child: ScannerOverlay(scanWindow: scanWindow),
            ),

          // 3. Barre d'outils supérieure (Fermer, Flash, Changer de caméra)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                    ),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                        ),
                        icon: Icon(
                          _isTorchOn ? Icons.flash_on : Icons.flash_off,
                          color: _isTorchOn ? Colors.amber : Colors.white,
                        ),
                        onPressed: _toggleTorch,
                      ),
                      if (_cameras.length > 1) ...[
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.black.withValues(alpha: 0.5),
                          ),
                          icon: const Icon(Icons.flip_camera_ios,
                              color: Colors.white),
                          onPressed: _switchCamera,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Carte d'état de détection inférieure
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: DetectionStatusCard(
                productName: _detectedProductName,
                isSearchingName: _isSearchingName,
                expirationDate: _detectedExpirationDate,
                onConfirm: _finishScanning,
                onManualEntry: _finishScanning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

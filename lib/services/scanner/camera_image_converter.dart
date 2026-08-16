import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// Utilitaire pour convertir un [CameraImage] natif en [InputImage]
/// utilisable par les modèles ML Kit (OCR & Barcode).
class CameraImageConverter {
  /// Convertit une frame [CameraImage] selon les spécifications de la caméra
  static InputImage? convertToInputImage({
    required CameraImage image,
    required CameraDescription camera,
  }) {
    try {
      final sensorOrientation = camera.sensorOrientation;
      final InputImageRotation? rotation =
          InputImageRotationValue.fromRawValue(sensorOrientation);
      if (rotation == null) {
        debugPrint('[SCANNER] ⚠️ Rotation inconnue pour sensorOrientation: $sensorOrientation');
        return null;
      }

      if (Platform.isAndroid) {
        // Sur Android avec YUV420_888 (3 plans), on convertit en NV21 valide
        final Uint8List nv21Bytes = _convertYuv420ToNv21(image);

        return InputImage.fromBytes(
          bytes: nv21Bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: image.width,
          ),
        );
      } else {
        // Sur iOS (BGRA8888, plan unique)
        return InputImage.fromBytes(
          bytes: image.planes.first.bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.bgra8888,
            bytesPerRow: image.planes.first.bytesPerRow,
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('[SCANNER] ❌ Erreur conversion CameraImage: $e\n$stack');
      return null;
    }
  }

  /// Convertit un CameraImage YUV_420_888 (3 plans) en buffer d'octets NV21 valide
  static Uint8List _convertYuv420ToNv21(CameraImage image) {
    if (image.planes.length == 1) {
      return image.planes[0].bytes;
    }

    final int width = image.width;
    final int height = image.height;
    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final Uint8List yBuffer = yPlane.bytes;
    final Uint8List uBuffer = uPlane.bytes;
    final Uint8List vBuffer = vPlane.bytes;

    final int numPixels = width * height;
    // NV21 = Y (width*height) + UV entrelacé (width*height/2)
    final Uint8List nv21 = Uint8List(numPixels + (numPixels ~/ 2));

    // 1. Copie du plan Y avec prise en compte des strides
    int nvIndex = 0;
    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      int yRowOffset = y * yRowStride;
      for (int x = 0; x < width; x++) {
        nv21[nvIndex++] = yBuffer[yRowOffset + x * yPixelStride];
      }
    }

    // 2. Entrelacement V et U (format NV21: V, U, V, U...)
    final int uvWidth = width ~/ 2;
    final int uvHeight = height ~/ 2;
    final int uRowStride = uPlane.bytesPerRow;
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vRowStride = vPlane.bytesPerRow;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < uvHeight; y++) {
      int uRowOffset = y * uRowStride;
      int vRowOffset = y * vRowStride;
      for (int x = 0; x < uvWidth; x++) {
        final int vOffset = vRowOffset + x * vPixelStride;
        final int uOffset = uRowOffset + x * uPixelStride;
        if (vOffset < vBuffer.length) {
          nv21[nvIndex++] = vBuffer[vOffset];
        }
        if (uOffset < uBuffer.length) {
          nv21[nvIndex++] = uBuffer[uOffset];
        }
      }
    }

    return nv21;
  }
}

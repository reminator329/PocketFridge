import 'package:flutter/material.dart';

/// Overlay visuel moderne avec cadre de visée et ligne de scan animée.
class ScannerOverlay extends StatefulWidget {
  final Rect scanWindow;

  const ScannerOverlay({
    super.key,
    required this.scanWindow,
  });

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return CustomPaint(
          painter: _ScannerPainter(
            scanWindow: widget.scanWindow,
            animationValue: _animController.value,
            primaryColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final Rect scanWindow;
  final double animationValue;
  final Color primaryColor;

  _ScannerPainter({
    required this.scanWindow,
    required this.animationValue,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    // 1. Fond semi-transparent avec découpe du viseur
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(18)),
      );

    final combinedPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );
    canvas.drawPath(combinedPath, backgroundPaint);

    // 2. Coins du viseur (Reticle corners)
    final cornerPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;
    const cornerRadius = 16.0;

    // Top-Left
    final topLeft = Path()
      ..moveTo(scanWindow.left, scanWindow.top + cornerLength)
      ..lineTo(scanWindow.left, scanWindow.top + cornerRadius)
      ..arcToPoint(
        Offset(scanWindow.left + cornerRadius, scanWindow.top),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(scanWindow.left + cornerLength, scanWindow.top);
    canvas.drawPath(topLeft, cornerPaint);

    // Top-Right
    final topRight = Path()
      ..moveTo(scanWindow.right - cornerLength, scanWindow.top)
      ..lineTo(scanWindow.right - cornerRadius, scanWindow.top)
      ..arcToPoint(
        Offset(scanWindow.right, scanWindow.top + cornerRadius),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(scanWindow.right, scanWindow.top + cornerLength);
    canvas.drawPath(topRight, cornerPaint);

    // Bottom-Left
    final bottomLeft = Path()
      ..moveTo(scanWindow.left, scanWindow.bottom - cornerLength)
      ..lineTo(scanWindow.left, scanWindow.bottom - cornerRadius)
      ..arcToPoint(
        Offset(scanWindow.left + cornerRadius, scanWindow.bottom),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(scanWindow.left + cornerLength, scanWindow.bottom);
    canvas.drawPath(bottomLeft, cornerPaint);

    // Bottom-Right
    final bottomRight = Path()
      ..moveTo(scanWindow.right - cornerLength, scanWindow.bottom)
      ..lineTo(scanWindow.right - cornerRadius, scanWindow.bottom)
      ..arcToPoint(
        Offset(scanWindow.right, scanWindow.bottom - cornerRadius),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(scanWindow.right, scanWindow.bottom - cornerLength);
    canvas.drawPath(bottomRight, cornerPaint);

    // 3. Ligne laser animée
    final laserY = scanWindow.top + (scanWindow.height * animationValue);
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withValues(alpha: 0.0),
          primaryColor.withValues(alpha: 0.8),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromLTWH(
          scanWindow.left,
          laserY,
          scanWindow.width,
          2.5,
        ),
      )
      ..strokeWidth = 2.5;

    canvas.drawLine(
      Offset(scanWindow.left + 10, laserY),
      Offset(scanWindow.right - 10, laserY),
      laserPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.scanWindow != scanWindow;
  }
}

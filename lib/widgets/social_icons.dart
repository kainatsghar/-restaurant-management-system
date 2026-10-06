import 'package:flutter/material.dart';

/// Pixel-perfect social login icons (Google, Facebook, Apple, Biometric/Phone)
class SocialIcons {
  SocialIcons._();

  /// Official Google 'G' Multi-color Logo (exact cubic bezier vector path)
  static Widget google({double size = 22}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }

  /// Facebook 'f' Logo in official blue
  static Widget facebook({double size = 22}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          'f',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.72,
            fontFamily: 'sans-serif',
            height: 1.1,
          ),
        ),
      ),
    );
  }

  /// Apple Logo in sleek black
  static Widget apple({double size = 22}) {
    return Icon(
      Icons.apple,
      color: Colors.black,
      size: size * 1.15,
    );
  }

  /// Biometric / Phone / Passkey Icon matching mockup
  static Widget passkey({double size = 22}) {
    return Icon(
      Icons.phone_android_rounded,
      color: const Color(0xFF4A5568),
      size: size,
    );
  }
}

/// Exact official Google 'G' vector path with official colors:
/// Blue (#4285F4), Green (#34A853), Yellow (#FBBC05), Red (#EA4335)
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24.0;
    canvas.scale(scale, scale);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // 1. Blue (#4285F4)
    paint.color = const Color(0xFF4285F4);
    final Path bluePath = Path()
      ..moveTo(23.49, 12.28)
      ..cubicTo(23.49, 11.48, 23.42, 10.71, 23.3, 9.96)
      ..lineTo(12.0, 9.96)
      ..lineTo(12.0, 14.63)
      ..lineTo(18.45, 14.63)
      ..cubicTo(18.17, 16.12, 17.33, 17.39, 16.06, 18.24)
      ..lineTo(19.98, 21.28)
      ..cubicTo(22.28, 19.16, 23.49, 16.03, 23.49, 12.28)
      ..close();
    canvas.drawPath(bluePath, paint);

    // 2. Green (#34A853)
    paint.color = const Color(0xFF34A853);
    final Path greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.96, 22.92, 19.98, 21.28)
      ..lineTo(16.06, 18.24)
      ..cubicTo(14.98, 18.96, 13.6, 19.39, 12.0, 19.39)
      ..cubicTo(8.87, 19.39, 6.22, 17.27, 5.27, 14.43)
      ..lineTo(1.23, 17.56)
      ..cubicTo(3.22, 21.52, 7.3, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, paint);

    // 3. Yellow (#FBBC05)
    paint.color = const Color(0xFFFBBC05);
    final Path yellowPath = Path()
      ..moveTo(5.27, 14.43)
      ..cubicTo(5.03, 13.71, 4.9, 12.94, 4.9, 12.0)
      ..cubicTo(4.9, 11.06, 5.03, 10.29, 5.27, 9.57)
      ..lineTo(1.23, 6.44)
      ..cubicTo(0.44, 8.01, 0.0, 9.95, 0.0, 12.0)
      ..cubicTo(0.0, 14.05, 0.44, 15.99, 1.23, 17.56)
      ..lineTo(5.27, 14.43)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // 4. Red (#EA4335)
    paint.color = const Color(0xFFEA4335);
    final Path redPath = Path()
      ..moveTo(12.0, 4.61)
      ..cubicTo(13.76, 4.61, 15.34, 5.22, 16.59, 6.41)
      ..lineTo(20.07, 2.93)
      ..cubicTo(17.95, 0.96, 15.23, 0.0, 12.0, 0.0)
      ..cubicTo(7.3, 0.0, 3.22, 2.48, 1.23, 6.44)
      ..lineTo(5.27, 9.57)
      ..cubicTo(6.22, 6.73, 8.87, 4.61, 12.0, 4.61)
      ..close();
    canvas.drawPath(redPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

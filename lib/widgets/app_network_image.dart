import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final IconData fallbackIcon;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = 0,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.fastfood_rounded,
  });

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F25),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          color: AppColors.primaryPink.withValues(alpha: 0.65),
          size: (height != null && height! > 0) ? (height! * 0.38) : 28,
        ),
      ),
    );
  }

  Uint8List? _tryDecodeBase64(String str) {
    try {
      String cleanStr = str.trim();
      if (cleanStr.startsWith('data:image')) {
        final commaIndex = cleanStr.indexOf(',');
        if (commaIndex != -1) {
          cleanStr = cleanStr.substring(commaIndex + 1);
        }
      }
      return base64Decode(cleanStr);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();

    if (cleanUrl.isEmpty) {
      return _buildFallback();
    }

    // 1. Check if it is Base64 encoded image
    if (cleanUrl.startsWith('data:image') || cleanUrl.length > 200 && !cleanUrl.startsWith('http')) {
      final bytes = _tryDecodeBase64(cleanUrl);
      if (bytes != null && bytes.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildFallback(),
          ),
        );
      }
    }

    // 2. Check if it is a local File path
    if (!cleanUrl.startsWith('http')) {
      try {
        final file = File(cleanUrl);
        if (file.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.file(
              file,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => _buildFallback(),
            ),
          );
        }
      } catch (_) {}
    }

    // 3. Network URL
    if (cleanUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          cleanUrl,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1F25),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryPink,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => _buildFallback(),
        ),
      );
    }

    return _buildFallback();
  }
}

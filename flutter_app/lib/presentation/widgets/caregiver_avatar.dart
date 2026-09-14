import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Circular avatar that handles three image sources in priority order:
///   1. HTTP/HTTPS URL  → CachedNetworkImage (with loading + error states)
///   2. Base64 string   → MemoryImage decoded in-place
///   3. No image        → Letter initial fallback
class CaregiverAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool isSuper;

  const CaregiverAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 64,
    this.isSuper = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl ?? '';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.3),
        border: isSuper ? Border.all(color: Colors.amber, width: 2.5) : null,
      ),
      child: ClipOval(child: _buildImage(url)),
    );
  }

  Widget _buildImage(String url) {
    // 1. Network URL
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => _shimmer(),
        errorWidget: (_, __, ___) => _letterFallback(),
      );
    }

    // 2. Base64 data URI or raw base64 string
    if (url.isNotEmpty) {
      try {
        final base64Str = url.contains(',') ? url.split(',').last : url;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _letterFallback());
      } catch (_) {}
    }

    // 3. Letter initial fallback
    return _letterFallback();
  }

  Widget _letterFallback() {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: size * 0.38,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _shimmer() {
    return Container(color: Colors.white.withOpacity(0.15));
  }
}

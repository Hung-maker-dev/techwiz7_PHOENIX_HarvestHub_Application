import 'package:flutter/material.dart';

import '../../../core/network/dio_client.dart';

class AdminProductThumbnail extends StatelessWidget {
  const AdminProductThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 48,
  });

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final uri = _resolveImageUri(imageUrl);
    final fallback = _placeholder(context);
    if (uri == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        uri.toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  Uri? _resolveImageUri(String? value) {
    final path = value?.trim();
    if (path == null || path.isEmpty) return null;
    final parsed = Uri.tryParse(path);
    if (parsed == null) return null;
    if (parsed.hasScheme) {
      return {'http', 'https'}.contains(parsed.scheme) && parsed.host.isNotEmpty
          ? parsed
          : null;
    }
    if (path.startsWith('//')) return null;
    final base = Uri.tryParse(kApiBaseUrl);
    if (base == null || !{'http', 'https'}.contains(base.scheme)) return null;
    return base.resolve(path.startsWith('/') ? path : '/$path');
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.imageBytes,
    this.size = 112,
    this.showEditBadge = false,
  });

  final String? imageUrl;
  final Uint8List? imageBytes;
  final double size;
  final bool showEditBadge;

  ImageProvider<Object>? _provider() {
    if (imageBytes != null) return MemoryImage(imageBytes!);
    final source = imageUrl?.trim();
    if (source == null || source.isEmpty) return null;
    if (source.startsWith('data:image/')) {
      try {
        return MemoryImage(base64Decode(source.split(',').last));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(source);
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF263238),
            border: Border.all(color: const Color(0xFF00C850), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x8800C850), blurRadius: 22),
            ],
            image: provider == null
                ? null
                : DecorationImage(image: provider, fit: BoxFit.cover),
          ),
          child: provider == null
              ? Icon(Icons.person_rounded,
                  color: Colors.white70, size: size * .52)
              : null,
        ),
        if (showEditBadge)
          Positioned(
            right: -2,
            bottom: 4,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF00C850),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
      ],
    );
  }
}

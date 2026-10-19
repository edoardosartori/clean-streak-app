import 'package:flutter/material.dart';

class TokenResolver {
  TokenResolver._();

  static dynamic resolveReference(
    String path,
    Map<String, dynamic> root,
  ) {
    final cleaned = path.replaceAll('{', '').replaceAll('}', '');

    dynamic current = root;

    for (final part in cleaned.split('.')) {
      if (current is! Map<String, dynamic>) {
        throw Exception('Invalid reference: $path');
      }

      current = current[part];
    }

    if (current == null) {
      throw Exception('Reference not found: $path');
    }

    if (current is Map<String, dynamic> && current.containsKey(r'$value')) {
      return current[r'$value'];
    }

    return current;
  }

  static Color parseColor(String hex) {
    final clean = hex.replaceAll('#', '');

    if (clean.length == 6) {
      return Color(
        int.parse(
          'FF$clean',
          radix: 16,
        ),
      );
    }

    if (clean.length == 8) {
      final rgb = clean.substring(0, 6);
      final alpha = clean.substring(6, 8);

      return Color(
        int.parse(
          '$alpha$rgb',
          radix: 16,
        ),
      );
    }

    throw FormatException(
      'Unsupported color format: $hex',
    );
  }
}

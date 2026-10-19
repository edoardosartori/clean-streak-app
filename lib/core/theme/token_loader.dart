import 'dart:convert';

import 'package:flutter/services.dart';

import 'fusion_tokens.dart';
import 'token_resolver.dart';

class TokenLoader {
  static Future<FusionTokens> load() async {
    final rawJson = await rootBundle.loadString(
      'assets/tokens/fusion-tokens.json',
    );

    final Map<String, dynamic> json = jsonDecode(rawJson);

    final flattened = <String, dynamic>{};

    void walk(
      Map<String, dynamic> node,
      String path,
    ) {
      node.forEach((key, value) {
        final current = path.isEmpty ? key : '$path.$key';

        if (value is Map<String, dynamic>) {
          if (value.containsKey(r'$value')) {
            var tokenValue = value[r'$value'];

            if (tokenValue is String && tokenValue.startsWith('{')) {
              tokenValue = TokenResolver.resolveReference(
                tokenValue,
                json,
              );
            }

            if (tokenValue is String && tokenValue.startsWith('#')) {
              tokenValue = TokenResolver.parseColor(
                tokenValue,
              );
            }

            flattened[current] = tokenValue;
          }

          walk(value, current);
        }
      });
    }

    walk(json, '');

    return FusionTokens(flattened);
  }
}

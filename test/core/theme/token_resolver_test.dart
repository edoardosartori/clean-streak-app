import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clean_streak/core/theme/token_resolver.dart';

void main() {
  test('resolves references', () {
    final root = {
      'a': {
        'b': {'\$value': '#FF0000'},
      },
    };

    final result = TokenResolver.resolveReference('{a.b}', root);

    expect(result, '#FF0000');
  });

  test('parses rgb', () {
    final color = TokenResolver.parseColor('#5B8CFF');

    expect(color, const Color(0xFF5B8CFF));
  });

  test('parses rgba css format', () {
    final color = TokenResolver.parseColor('#00F0FF1F');

    expect(color, const Color(0x1F00F0FF));
  });

  test('throws invalid color', () {
    expect(() => TokenResolver.parseColor('#FFF'), throwsFormatException);
  });
}

import 'package:flutter/material.dart';

class FusionTokens {
  final Map<String, dynamic> values;

  const FusionTokens(this.values);

  T get<T>(String key) {
    final value = values[key];

    if (value == null) {
      throw Exception('Token not found: $key');
    }

    return value as T;
  }

  Color color(String key) => get<Color>(key);

  double dimension(String key) {
    final value = get<dynamic>(key);

    if (value is int) {
      return value.toDouble();
    }

    return value as double;
  }

  String text(String key) => get<String>(key);
}

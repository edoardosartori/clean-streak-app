import 'package:flutter/material.dart';

import '../layouts/landscape_layout.dart';
import '../layouts/portrait_layout.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return const LandscapeLayout();
    }

    return const PortraitLayout();
  }
}

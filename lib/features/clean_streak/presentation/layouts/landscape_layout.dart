import 'package:flutter/material.dart';

import 'portrait_layout.dart';

// TODO(landscape): dedicated landscape layout.
class LandscapeLayout extends StatelessWidget {
  const LandscapeLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return const PortraitLayout();
  }
}

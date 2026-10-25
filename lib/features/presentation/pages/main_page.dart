import 'package:flutter/material.dart';

import '../layouts/landscape_layout.dart';
import '../layouts/portrait_layout.dart';

/// Root page of the tracker feature. Picks the layout from the
/// orientation, same convention as the other apps of the suite.
class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape
        ? const LandscapeLayout()
        : const PortraitLayout();
  }
}

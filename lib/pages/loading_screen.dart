import 'package:flutter/material.dart';

import '../ui/components.dart';
import '../ui/game_widgets.dart';

/// Shown while the app gets ready (resuming a saved session): the cards and the logo of the login page.
/// `web/index.html` draws the same while the app downloads, so the page does not change when it starts.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecorativeCardFan(cardWidth: 64),
          SizedBox(height: 24),
          AppLogo(height: 42),
          SizedBox(height: 28),
          CircularProgressIndicator(),
        ],
      ),
    );
  }
}

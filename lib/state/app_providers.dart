import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app_controller.dart';

/// Makes the app state available to the widgets: the root, which decides the screen, and its two parts,
/// which pages watch separately so that a change in one does not rebuild what depends only on the other.
class AppProviders extends StatelessWidget {
  const AppProviders({super.key, required this.app, required this.child});

  final AppController app;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app),
        ChangeNotifierProvider.value(value: app.session),
        ChangeNotifierProvider.value(value: app.match),
      ],
      child: child,
    );
  }
}

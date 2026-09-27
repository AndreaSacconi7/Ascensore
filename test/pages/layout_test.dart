import 'package:ascensore_client/pages/choose_nickname_page.dart';
import 'package:ascensore_client/pages/game/waiting_view.dart';
import 'package:ascensore_client/pages/login_page.dart';
import 'package:ascensore_client/pages/main_menu_screen.dart';
import 'package:ascensore_client/pages/session_replaced_page.dart';
import 'package:ascensore_client/state/app_controller.dart';
import 'package:ascensore_client/state/app_providers.dart';
import 'package:ascensore_client/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

// Phones small and large, landscape, and a short desktop browser window
const sizes = {
  'iPhone SE (1st gen)': Size(320, 568),
  'small Android': Size(360, 640),
  'iPhone SE': Size(375, 667),
  'iPhone 15': Size(393, 852),
  'phone landscape': Size(844, 390),
  'short browser window': Size(1280, 620),
};

// Screens that need no match in progress
final screens = <String, Widget Function()>{
  'menu': () => const MainMenuScreen(),
  'login': () => const LoginPage(),
  'nickname': () => const ChooseNicknamePage(),
  'waiting room': () => const WaitingView(),
  'session replaced': () => const SessionReplacedPage(),
};

void main() {
  Future<void> show(WidgetTester tester, Widget screen, Size size, {double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final app = AppController(auth: FakeAuthService(), connector: FakeConnector().call);
    await tester.pumpWidget(AppProviders(
      app: app,
      child: MaterialApp(theme: AppTheme.dark(), home: Scaffold(body: screen)),
    ));
    await tester.pump(const Duration(seconds: 1));
  }

  for (final screen in screens.entries) {
    group(screen.key, () {
      for (final size in sizes.entries) {
        testWidgets('fits on ${size.key} (${size.value.width.toInt()}x${size.value.height.toInt()})', (tester) async {
          await show(tester, screen.value(), size.value);
          // A RenderFlex overflow is reported as an exception
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('fits with large text on a small phone', (tester) async {
        await show(tester, screen.value(), const Size(375, 667), textScale: 1.3);
        expect(tester.takeException(), isNull);
      });
    });
  }
}

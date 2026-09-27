import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ascensore_client/pages/choose_nickname_page.dart';
import 'package:ascensore_client/pages/game_over_screen.dart';
import 'package:ascensore_client/pages/game_screen.dart';
import 'package:ascensore_client/pages/loading_screen.dart';
import 'package:ascensore_client/pages/login_page.dart';
import 'package:ascensore_client/pages/main_menu_screen.dart';
import 'package:ascensore_client/pages/session_replaced_page.dart';

import 'app_screen_state.dart';
import 'network/server_link.dart';
import 'state/app_controller.dart';
import 'state/match_controller.dart';
import 'state/session_controller.dart';
import 'ui/components.dart';
import 'ui/theme.dart';

/// Shared background, the page for the current screen, server notices as snackbars,
/// and a banner while the connection is being restored.
class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  MatchController? _match;

  @override
  void initState() {
    super.initState();
    // Resumes the saved profile, if any, so the player is known by the time they reach the menu
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<SessionController>().checkLoginStatus());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final match = context.read<MatchController>();
    if (match != _match) {
      _match?.removeListener(_showNotice);
      _match = match..addListener(_showNotice);
    }
  }

  @override
  void dispose() {
    _match?.removeListener(_showNotice);
    super.dispose();
  }

  void _showNotice() {
    final notice = _match?.consumeNotice();
    if (notice == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(notice)));
  }

  @override
  Widget build(BuildContext context) {
    final screen = context.select<AppController, AppScreenState>((app) => app.screen);
    // Offline matches do not need the connection, so its state is not shown during them
    final offline = context.select<MatchController, bool>((m) => m.isOffline);
    final linkState = context.select<SessionController, LinkState>((s) => s.linkState);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppBackground(
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              child: KeyedSubtree(key: ValueKey(screen), child: _buildScreen(screen)),
            ),
            if (linkState == LinkState.reconnecting && !offline) const _ReconnectingBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildScreen(AppScreenState state) {
    switch (state) {
      case AppScreenState.loading:
        return const LoadingScreen();
      case AppScreenState.login:
        return const LoginPage();
      case AppScreenState.chooseNickname:
        return const ChooseNicknamePage();
      case AppScreenState.mainMenu:
        return const MainMenuScreen();
      case AppScreenState.inGame:
        return const GameScreen();
      case AppScreenState.sessionReplaced:
        return const SessionReplacedPage();
      case AppScreenState.gameOver:
        return const GameOverScreen();
    }
  }
}

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xCC8A4B0F),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Connessione persa · riconnessione…',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../message/player_info_response.dart';
import '../ui/components.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';
import '../state/session_controller.dart';
import '../state/app_controller.dart';

/// Shown once per account: the public name other players see (never the email address).
class ChooseNicknamePage extends StatefulWidget {
  const ChooseNicknamePage({super.key});

  /// Same rule as the server: 3 to 16 letters, digits or underscores.
  static final nicknamePattern = RegExp(r'^[A-Za-z0-9_]{3,16}$');

  @override
  State<ChooseNicknamePage> createState() => _ChooseNicknamePageState();
}

class _ChooseNicknamePageState extends State<ChooseNicknamePage> {
  final _controller = TextEditingController();
  String? _localError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _localError = null));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(SessionController manager) {
    final nickname = _controller.text.trim();
    if (!ChooseNicknamePage.nicknamePattern.hasMatch(nickname)) {
      setState(() => _localError = 'Da 3 a 16 caratteri: lettere, numeri o _');
      return;
    }
    manager.submitNickname(nickname);
  }

  String? _serverErrorText(String? code) => switch (code) {
        PlayerInfoResponse.nicknameTaken => 'Questo nickname è già in uso, scegline un altro.',
        PlayerInfoResponse.nicknameInvalid => 'Da 3 a 16 caratteri: lettere, numeri o _',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<SessionController>();
    final error = _localError ?? _serverErrorText(manager.nicknameError);
    final nickname = _controller.text.trim();

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: PlayerAvatar(nickname: nickname.isEmpty ? '?' : nickname, size: 72),
                ),
                const SizedBox(height: 20),
                Text(
                  'Come ti chiamano al tavolo?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Il nickname è l\'unica cosa che gli altri giocatori vedono di te.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _controller,
                        maxLength: 16,
                        autofocus: true,
                        onSubmitted: (_) => _submit(manager),
                        decoration: InputDecoration(
                          hintText: 'Nickname',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          counterStyle: const TextStyle(color: AppColors.textMuted),
                          errorText: error,
                          errorMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'CONTINUA',
                        loading: manager.submittingNickname,
                        onPressed: () => _submit(manager),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // An anonymous profile is not signed out of (it would be lost): the player just goes back
                if (manager.emailAccounts)
                  AppButton(label: 'Esci', style: AppButtonStyle.ghost, onPressed: manager.logOut)
                else
                  AppButton(
                    label: 'Annulla',
                    style: AppButtonStyle.ghost,
                    onPressed: context.read<AppController>().cancelNickname,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

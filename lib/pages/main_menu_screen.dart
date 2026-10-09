import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ui/components.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';
import '../state/app_controller.dart';
import '../state/match_controller.dart';
import '../state/session_controller.dart';
import 'offline_sheet.dart';
import 'rules_sheet.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  late int _players = context.read<MatchController>().matchSize;
  late int _bots = context.read<MatchController>().offlineBots;
  // Against the bots by default: someone opening the link can play at once instead of waiting alone in a queue
  bool _offline = true;

  // Below this height the decorative cards are left out; below the content's own height the page scrolls
  static const _compactHeight = 720.0;

  @override
  Widget build(BuildContext context) {
    // Creating the profile and connecting before the first online match
    final joining = context.select<AppController, bool>((app) => app.joining);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Phones in landscape and wide, short windows: the logo beside the panel
          final sideBySide = constraints.maxWidth >= 700 && constraints.maxHeight < 600;
          final compact = constraints.maxHeight < _compactHeight;
          return FillOrScroll(
            maxWidth: sideBySide ? 960 : 480,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: sideBySide ? _sideBySide(joining: joining) : _stacked(showCards: !compact, joining: joining),
          );
        },
      ),
    );
  }

  Widget _stacked({required bool showCards, required bool joining}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(),
        const Spacer(),
        _Brand(showCards: showCards),
        const Spacer(),
        const SizedBox(height: 16),
        _newMatchPanel(joining: joining),
        const SizedBox(height: 12),
        const _RulesButton(),
      ],
    );
  }

  Widget _sideBySide({required bool joining}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              const Expanded(child: Center(child: _Brand(showCards: false))),
              const SizedBox(width: 24),
              SizedBox(
                width: 400,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_newMatchPanel(joining: joining), const SizedBox(height: 12), const _RulesButton()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _newMatchPanel({required bool joining}) {
    final match = context.read<MatchController>();
    final textTheme = Theme.of(context).textTheme;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Nuova partita', style: textTheme.titleMedium, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              const StatChip(icon: Icons.layers_rounded, value: '19 mani', color: AppColors.gold),
            ],
          ),
          const SizedBox(height: 12),
          _ModeSwitch(offline: _offline, onChanged: (offline) => setState(() => _offline = offline)),
          const SizedBox(height: 12),
          if (_offline)
            BotCountSelector(value: _bots, onChanged: (bots) => setState(() => _bots = bots))
          else
            Row(
              children: [
                for (final players in const [2, 3, 4]) ...[
                  if (players > 2) const SizedBox(width: 10),
                  Expanded(
                    child: CountOption(
                      count: players,
                      label: 'giocatori',
                      icon: Icons.person_rounded,
                      selected: _players == players,
                      onTap: () => setState(() => _players = players),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 12),
          Text(
            _offline
                ? 'Contro il computer, anche senza connessione.'
                : 'La partita parte quando ci sono $_players giocatori.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'GIOCA',
            icon: _offline ? Icons.smart_toy_rounded : Icons.play_arrow_rounded,
            loading: !_offline && joining,
            onPressed: () =>
                _offline ? match.playOffline(bots: _bots) : context.read<AppController>().playOnline(players: _players),
          ),
        ],
      ),
    );
  }
}

/// Who is playing, and the way out (only for email accounts: an anonymous profile is never signed out of).
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    final nickname = context.select<SessionController, String?>((s) => s.nickname);
    final canSignOut = context.select<SessionController, bool>((s) => s.canSignOut);
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        if (nickname != null) ...[
          PlayerAvatar(nickname: nickname, size: 44),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: nickname != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ciao,', style: textTheme.bodyMedium),
                    Text(nickname, style: textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                  ],
                )
              // No profile yet: nothing to fill in until the first online match
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ciao!', style: textTheme.titleLarge),
                    Text('Il nickname lo scegli alla prima partita online.', style: textTheme.bodyMedium),
                  ],
                ),
        ),
        if (canSignOut)
          IconButton(
            tooltip: 'Esci',
            onPressed: session.logOut,
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

/// Logo and tagline, over a fan of cards when there is room for it.
class _Brand extends StatelessWidget {
  final bool showCards;

  const _Brand({required this.showCards});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCards) ...[
          const DecorativeCardFan(cardWidth: 76),
          const SizedBox(height: 24),
        ],
        const AppLogo(height: 44),
        const SizedBox(height: 8),
        Text(
          'Scommetti le tue prese, mano dopo mano,\nsalendo fino a 10 carte e ridiscendendo.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
      ],
    );
  }
}

class _RulesButton extends StatelessWidget {
  const _RulesButton();

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Come si gioca',
      icon: Icons.menu_book_rounded,
      style: AppButtonStyle.secondary,
      onPressed: () => showRulesSheet(context),
    );
  }
}

/// Online against other players, or offline against the computer.
class _ModeSwitch extends StatelessWidget {
  final bool offline;
  final ValueChanged<bool> onChanged;

  const _ModeSwitch({required this.offline, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          _segment('Online', Icons.public_rounded, !offline, () => onChanged(false)),
          _segment('Contro i bot', Icons.smart_toy_rounded, offline, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _segment(String label, IconData icon, bool selected, VoidCallback onTap) {
    final color = selected ? AppColors.textPrimary : AppColors.textMuted;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

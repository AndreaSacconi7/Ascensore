import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ui/components.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';
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
  bool _offline = false;

  @override
  Widget build(BuildContext context) {
    final match = context.read<MatchController>();
    final session = context.read<SessionController>();
    final nickname = context.select<SessionController, String>((s) => s.nickname ?? '');
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: ContentWidth(
        maxWidth: 480,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PlayerAvatar(nickname: nickname, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ciao,', style: textTheme.bodyMedium),
                        Text(nickname, style: textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Esci',
                    onPressed: session.logOut,
                    icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Spacer(),
              const Center(child: DecorativeCardFan(cardWidth: 76)),
              const SizedBox(height: 24),
              const Center(child: AppLogo(height: 44)),
              const SizedBox(height: 8),
              Text(
                'Scommetti le tue prese, mano dopo mano,\nsalendo fino a 10 carte e ridiscendendo.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const Spacer(),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('Nuova partita', style: textTheme.titleMedium),
                        const Spacer(),
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
                      onPressed: () => _offline ? match.playOffline(bots: _bots) : match.joinGame(players: _players),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Come si gioca',
                icon: Icons.menu_book_rounded,
                style: AppButtonStyle.secondary,
                onPressed: () => showRulesSheet(context),
              ),
            ],
          ),
        ),
      ),
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
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

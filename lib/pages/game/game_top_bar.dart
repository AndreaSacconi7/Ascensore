import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../model/game.dart';
import '../../model/player_state.dart';
import '../../ui/game_widgets.dart';
import '../../ui/theme.dart';
import '../rules_sheet.dart';
import '../../state/match_controller.dart';

/// Where the match is (elevator floor), the briscola, and the rules.
class GameTopBar extends StatelessWidget {
  final Game game;

  const GameTopBar({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final briscola = game.briscola;
    return Row(
      children: [
        FloorIndicator(
          handSize: game.set,
          setNumber: game.setNumber,
          totalSets: game.totalSets,
          goingUp: game.goingUp,
          peak: game.isPeakSet,
        ),
        const Spacer(),
        Tooltip(
          message: briscola == null && game.isPeakSet
              ? 'Mano da ${game.maxHandSize}: la briscola è il seme della prima carta di ogni presa'
              : 'Briscola',
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('BRISCOLA',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1.4)),
                  Text(
                    briscola == null ? (game.isPeakSet ? '1ª carta' : '–') : _seedName(briscola.seed.name),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              briscola == null
                  ? const EmptyCardSlot(width: 34, icon: Icons.question_mark_rounded)
                  : PlayingCard(card: briscola, width: 34, highlighted: true),
            ],
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Come si gioca',
          onPressed: () => showRulesSheet(context),
          icon: const Icon(Icons.help_outline_rounded, color: AppColors.textSecondary),
        ),
        IconButton(
          tooltip: 'Abbandona la partita',
          onPressed: () => _confirmLeave(context),
          icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final others = game.players.where((p) => p.playerState != PlayerState.EXIT).length - 1;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.large)),
        title: const Text('Abbandonare la partita?'),
        content: Text(
          others <= 1
              ? 'Non potrai rientrare e la partita finirà: vincerà l\'altro giocatore.'
              : 'Non potrai rientrare. Gli altri giocatori continueranno senza di te.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Resta', style: TextStyle(color: AppColors.textPrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abbandona', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) {
      context.read<MatchController>().leaveGame();
    }
  }

  static String _seedName(String seed) => switch (seed) {
        'COINS' => 'Denari',
        'CUPS' => 'Coppe',
        'SWORDS' => 'Spade',
        'STICKS' => 'Bastoni',
        _ => seed,
      };
}

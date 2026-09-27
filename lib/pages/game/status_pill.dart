import 'package:flutter/material.dart';

import '../../model/game.dart';
import '../../model/player.dart';
import '../../model/player_state.dart';
import '../../ui/theme.dart';

/// One line that always says what is happening: whose turn it is, or who took the trick.
class StatusPill extends StatelessWidget {
  final Game game;
  final Player me;

  const StatusPill({super.key, required this.game, required this.me});

  @override
  Widget build(BuildContext context) {
    final (text, icon, highlight) = _describe();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: text == null
          ? const SizedBox(height: 36, key: ValueKey('none'))
          : Container(
              key: ValueKey(text),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: highlight ? AppColors.gold.withValues(alpha: 0.16) : AppColors.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: highlight ? AppColors.gold.withValues(alpha: 0.6) : AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: highlight ? AppColors.gold : AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: highlight ? AppColors.gold : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  (String?, IconData, bool) _describe() {
    final winner = game.trickWinner;
    if (winner != null) {
      return (
        winner == me.nickname ? 'Presa tua!' : 'Presa di $winner',
        Icons.emoji_events_rounded,
        winner == me.nickname
      );
    }
    switch (me.playerState) {
      case PlayerState.BET:
        return ('Tocca a te: scommetti', Icons.flag_rounded, true);
      case PlayerState.PUT:
        return ('Tocca a te: gioca una carta', Icons.touch_app_rounded, true);
      default:
        break;
    }
    for (final p in game.players) {
      if (p.playerState == PlayerState.BET) {
        return ('${p.nickname} sta scommettendo…', Icons.hourglass_top_rounded, false);
      }
      if (p.playerState == PlayerState.PUT) {
        return ('Tocca a ${p.nickname}…', Icons.hourglass_top_rounded, false);
      }
    }
    return (null, Icons.circle, false);
  }
}

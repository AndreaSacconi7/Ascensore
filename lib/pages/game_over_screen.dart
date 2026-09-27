import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/player.dart';
import '../model/player_state.dart';
import '../state/match_controller.dart';
import '../state/session_controller.dart';
import '../ui/components.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  static const _medals = [Color(0xFFF5C451), Color(0xFFC9D1E0), Color(0xFFD08A4E)];

  @override
  Widget build(BuildContext context) {
    final match = context.watch<MatchController>();
    final isGuest = context.select<SessionController, bool>((s) => s.isGuest);
    final game = match.game;
    final me = match.me;
    if (game == null || me == null) return const SizedBox.shrink();

    final ranking = List.of(game.players)..sort((a, b) => b.score.compareTo(a.score));
    final myPosition = ranking.indexOf(me) + 1;
    final won = myPosition == 1;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: ContentWidth(
        maxWidth: 480,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: won ? AppColors.goldGradient : null,
                    color: won ? null : AppColors.surfaceStrong,
                    boxShadow: [if (won) BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 40)],
                  ),
                  child: Icon(
                    won ? Icons.emoji_events_rounded : Icons.flag_rounded,
                    size: 52,
                    color: won ? AppColors.onGold : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(won ? 'Hai vinto!' : 'Partita finita', textAlign: TextAlign.center, style: textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                won ? 'Sei arrivato in cima all\'ascensore.' : 'Ti sei classificato $myPosition° su ${ranking.length}.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              GlassPanel(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (var i = 0; i < ranking.length; i++)
                      _RankingRow(
                          position: i + 1,
                          player: ranking[i],
                          isMe: ranking[i] == me,
                          medal: i < 3 ? _medals[i] : null),
                  ],
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'GIOCA ANCORA',
                icon: Icons.replay_rounded,
                // Same kind of match: online with the same size, or offline with the same bots
                onPressed: match.playAgain,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: isGuest ? 'Esci' : 'Torna al menu',
                style: AppButtonStyle.secondary,
                onPressed: match.backToMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int position;
  final Player player;
  final bool isMe;
  final Color? medal;

  const _RankingRow({required this.position, required this.player, required this.isMe, this.medal});

  @override
  Widget build(BuildContext context) {
    final left = player.playerState == PlayerState.EXIT;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.gold.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: medal == null
                ? Text('$position', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))
                : Icon(Icons.workspace_premium_rounded, color: medal),
          ),
          const SizedBox(width: 8),
          PlayerAvatar(nickname: player.nickname, size: 34, faded: left, bot: player.isBot),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? '${player.nickname} (tu)' : player.nickname,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: isMe ? FontWeight.w800 : FontWeight.w600),
            ),
          ),
          Text(
            left ? 'uscito' : '${player.score} pt',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: left ? AppColors.textMuted : (position == 1 ? AppColors.gold : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

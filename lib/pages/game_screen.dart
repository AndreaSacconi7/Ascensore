import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/card_game.dart';
import '../model/game.dart';
import '../model/game_rules.dart';
import '../model/my_self_player.dart';
import '../model/player_state.dart';
import '../model/set_result_animation_state.dart';
import '../state/match_controller.dart';
import '../ui/components.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';
import 'game/bet_panel.dart';
import 'game/game_top_bar.dart';
import 'game/hand_fan.dart';
import 'game/opponent_tile.dart';
import 'game/seating.dart';
import 'game/set_result_toast.dart';
import 'game/status_pill.dart';
import 'game/table_view.dart';
import 'game/waiting_view.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MatchController>(
      builder: (context, match, _) {
        final game = match.game;
        final me = match.me;
        if (game == null || me == null) {
          return const WaitingView();
        }
        return Stack(
          children: [
            SafeArea(child: ContentWidth(maxWidth: 720, child: _Table(match: match, game: game, me: me))),
            if (match.lastSetResult != SetResultAnimationState.none)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: SetResultToast(
                      won: match.lastSetResult == SetResultAnimationState.win,
                      delta: match.lastSetDelta,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Table extends StatelessWidget {
  final MatchController match;
  final Game game;
  final MySelfPlayer me;

  const _Table({required this.match, required this.game, required this.me});

  bool get _canPlay => me.playerState == PlayerState.PUT;

  // Mirrors the server rule so the hand can dim cards you may not play
  bool _isPlayable(CardGame card) {
    final leader = game.playerOrder.isEmpty ? null : game.playerOrder.first;
    final leadCard = leader == me ? null : leader?.playedCard;
    return GameRules.isValidCard(leadCard: leadCard, hand: me.handCards, card: card);
  }

  void _explainBlocked(BuildContext context) {
    final lead = game.playerOrder.first.playedCard;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(lead == null ? 'Non puoi giocare questa carta.' : 'Devi rispondere al seme della prima carta.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final opponents = opponentsFrom(game, me);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: GameTopBar(game: game),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: opponents.length == 1
              ? SizedBox(width: 160, child: OpponentTile(player: opponents.first))
              : Row(
                  children: [
                    for (var i = 0; i < opponents.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: OpponentTile(player: opponents[i])),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TableView(
              game: game,
              me: me,
              opponents: opponents,
              canDrop: (card) => _canPlay && _isPlayable(card),
              onDrop: match.putCard,
              // Betting happens on the empty table, so your hand stays visible below
              overlay: me.playerState == PlayerState.BET
                  ? BetPanel(key: ValueKey('bet-${game.setNumber}'), game: game, me: me, onBet: match.setBet)
                  : null,
            ),
          ),
        ),
        // While you bet, the panel on the table already says so: give the table the room instead
        if (me.playerState != PlayerState.BET) ...[
          const SizedBox(height: 12),
          StatusPill(game: game, me: me),
        ],
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            radius: AppRadius.medium,
            child: Row(
              children: [
                PlayerAvatar(
                  nickname: me.nickname,
                  size: 34,
                  active: isOnTurn(me),
                  turnDeadline: me.turnDeadline,
                  turnLength: me.turnLength,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tu', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        me.nickname,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PlayerStats(player: me),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: HandFan(
            cards: me.handCards,
            canPlay: _canPlay,
            isPlayable: _isPlayable,
            onPlay: match.putCard,
            onBlocked: (_) => _explainBlocked(context),
          ),
        ),
      ],
    );
  }
}

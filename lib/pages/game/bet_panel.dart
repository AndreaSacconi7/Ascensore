import 'package:flutter/material.dart';

import '../../model/game.dart';
import '../../model/game_rules.dart';
import '../../model/player.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// Your bet, placed on the table itself so your hand stays in view below it.
class BetPanel extends StatefulWidget {
  final Game game;
  final Player me;
  final void Function(int bet) onBet;

  const BetPanel({super.key, required this.game, required this.me, required this.onBet});

  @override
  State<BetPanel> createState() => _BetPanelState();
}

class _BetPanelState extends State<BetPanel> {
  int? _bet;
  bool _sent = false;

  void _confirm() {
    final bet = _bet;
    if (bet == null) return;
    setState(() => _sent = true);
    widget.onBet(bet);
    // The panel disappears when the server accepts the bet; allow a retry if it does not
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _sent = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final handSize = game.set;
    final forbidden = GameRules.forbiddenBet(
      playerOrder: game.playerOrder,
      myNickname: widget.me.nickname,
      cardsInHand: handSize,
    );

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      // Scrolls only as a last resort on very small screens
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Quante prese farai?', style: TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(
                        text: '  ${handSize == 1 ? '1 carta' : '$handSize carte'}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var value = 0; value <= handSize; value++)
                  _BetOption(
                    value: value,
                    selected: _bet == value,
                    forbidden: value == forbidden,
                    onTap: _sent ? null : () => setState(() => _bet = value),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    forbidden == null ? 'Le tue carte sono qui sotto.' : 'Sei l\'ultimo: non puoi dire $forbidden.',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: _bet == null ? 'SCEGLI' : 'CONFERMA $_bet',
                  loading: _sent,
                  expand: false,
                  height: 42,
                  onPressed: _bet == null ? null : _confirm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BetOption extends StatelessWidget {
  final int value;
  final bool selected;
  final bool forbidden;
  final VoidCallback? onTap;

  const _BetOption({required this.value, required this.selected, required this.forbidden, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: forbidden ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: selected ? AppColors.goldGradient : null,
          color: selected ? null : AppColors.surfaceStrong,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: selected ? Colors.transparent : AppColors.border),
        ),
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.onGold : (forbidden ? AppColors.textMuted : AppColors.textPrimary),
              decoration: forbidden ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.danger,
              decorationThickness: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

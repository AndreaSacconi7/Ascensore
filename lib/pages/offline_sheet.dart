import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ui/components.dart';
import '../ui/theme.dart';
import '../state/match_controller.dart';

/// Pick how many computer opponents to play against, then start right away (no account needed).
Future<void> showOfflineSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => const _OfflineSheet(),
  );
}

class _OfflineSheet extends StatefulWidget {
  const _OfflineSheet();

  @override
  State<_OfflineSheet> createState() => _OfflineSheetState();
}

class _OfflineSheetState extends State<_OfflineSheet> {
  late int _bots = context.read<MatchController>().offlineBots;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Gioca contro i bot', style: textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Offline e senza account: la partita gira sul tuo dispositivo.', style: textTheme.bodyMedium),
            const SizedBox(height: 18),
            BotCountSelector(value: _bots, onChanged: (bots) => setState(() => _bots = bots)),
            const SizedBox(height: 20),
            AppButton(
              label: 'GIOCA',
              icon: Icons.smart_toy_rounded,
              onPressed: () {
                Navigator.of(context).pop();
                context.read<MatchController>().playOffline(bots: _bots);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 1, 2 or 3 computer opponents.
class BotCountSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const BotCountSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final bots in const [1, 2, 3]) ...[
          if (bots > 1) const SizedBox(width: 10),
          Expanded(
            child: CountOption(
              count: bots,
              label: 'bot',
              icon: Icons.smart_toy_rounded,
              selected: value == bots,
              onTap: () => onChanged(bots),
            ),
          ),
        ],
      ],
    );
  }
}

/// One choice of a count, drawn as that many little icons.
class CountOption extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const CountOption({
    super.key,
    required this.count,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: '$count $label',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold.withValues(alpha: 0.14) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: selected ? AppColors.gold : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [for (var i = 0; i < count; i++) Icon(icon, size: 16, color: color)],
              ),
              const SizedBox(height: 4),
              Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

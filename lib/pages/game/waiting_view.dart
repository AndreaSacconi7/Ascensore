import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ui/components.dart';
import '../../ui/game_widgets.dart';
import '../../ui/theme.dart';
import '../../state/match_controller.dart';
import '../../state/session_controller.dart';

/// Matchmaking: an elevator riding up and down, the seats already taken and those still free.
class WaitingView extends StatefulWidget {
  const WaitingView({super.key});

  @override
  State<WaitingView> createState() => _WaitingViewState();
}

class _WaitingViewState extends State<WaitingView> with SingleTickerProviderStateMixin {
  late final AnimationController _ride = AnimationController(vsync: this, duration: const Duration(seconds: 7))
    ..repeat();

  @override
  void dispose() {
    _ride.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = context.watch<MatchController>();
    final myNickname = context.select<SessionController, String?>((s) => s.nickname);
    final room = match.waitingRoom;
    final size = room?.playersPerMatch ?? match.matchSize;
    final joined = room?.players ?? const <String>[];
    final missing = (size - joined.length).clamp(0, size);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: FillOrScroll(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            AnimatedBuilder(
              animation: _ride,
              builder: (context, _) {
                // One ride: floors 1..10 and back down, like a match
                final step = (_ride.value * 19).floor().clamp(0, 18);
                final floor = step < 10 ? step + 1 : 19 - step;
                return FloorIndicator(
                  handSize: floor,
                  setNumber: step + 1,
                  totalSets: 19,
                  goingUp: step < 9,
                  peak: step == 9,
                );
              },
            ),
            const SizedBox(height: 28),
            Text('Partita a $size giocatori', style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              missing == 0 ? 'Si parte!' : (missing == 1 ? 'Manca 1 giocatore…' : 'Mancano $missing giocatori…'),
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < size; i++)
                    i < joined.length ? _Seat(nickname: joined[i], isMe: joined[i] == myNickname) : const _EmptySeat(),
                ],
              ),
            ),
            const Spacer(),
            AppButton(
              label: 'Annulla',
              icon: Icons.close_rounded,
              style: AppButtonStyle.secondary,
              onPressed: match.leaveGame,
            ),
          ],
        ),
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  final String nickname;
  final bool isMe;

  const _Seat({required this.nickname, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          PlayerAvatar(nickname: nickname, size: 46),
          const SizedBox(height: 8),
          Text(
            isMe ? 'Tu' : nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: isMe ? AppColors.gold : AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _EmptySeat extends StatelessWidget {
  const _EmptySeat();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
              color: AppColors.surface,
            ),
            child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.textMuted, size: 24),
          ),
          const SizedBox(height: 8),
          const Text('in attesa', style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

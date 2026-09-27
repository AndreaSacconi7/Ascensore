import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ui/components.dart';
import '../ui/theme.dart';
import '../state/session_controller.dart';

/// The account is now in use on another device; nothing reconnects until the player asks.
class SessionReplacedPage extends StatelessWidget {
  const SessionReplacedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.read<SessionController>();
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceStrong),
                    child: const Icon(Icons.devices_other_rounded, size: 42, color: AppColors.gold),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Stai giocando su un altro dispositivo',
                    textAlign: TextAlign.center, style: textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Il tuo account è stato aperto altrove, quindi qui ci siamo disconnessi. '
                  'Se giochi qui, l\'altro dispositivo verrà disconnesso.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 28),
                AppButton(label: 'GIOCA QUI', icon: Icons.phone_iphone_rounded, onPressed: manager.playHere),
                const SizedBox(height: 12),
                AppButton(label: 'Esci', style: AppButtonStyle.secondary, onPressed: manager.logOut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

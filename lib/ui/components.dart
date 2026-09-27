import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Night-blue gradient with two soft glows; every screen sits on it.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.backgroundTop, AppColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(top: -120, left: -80, child: _Glow(color: Color(0xFF5B6CFF), size: 320)),
          const Positioned(bottom: -140, right: -100, child: _Glow(color: Color(0xFF1C9C77), size: 360)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;

  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// Frosted panel for grouped content.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadius.large,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor ?? AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

enum AppButtonStyle { primary, secondary, ghost }

/// Pill button. Primary is gold for the main action of a screen; [loading] replaces the label.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonStyle style;
  final bool loading;
  final bool expand;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = AppButtonStyle.primary,
    this.loading = false,
    this.expand = true,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final isPrimary = style == AppButtonStyle.primary;
    final foreground = isPrimary ? AppColors.onGold : AppColors.textPrimary;

    final content = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20, color: foreground), const SizedBox(width: 10)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: height < 50 ? 14 : 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          );

    final decoration = switch (style) {
      AppButtonStyle.primary => BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
      AppButtonStyle.secondary => BoxDecoration(
          color: AppColors.surfaceStrong,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.border),
        ),
      AppButtonStyle.ghost => const BoxDecoration(),
    };

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled || loading ? 1 : 0.45,
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              width: expand ? double.infinity : null,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: height < 50 ? 18 : 24),
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hand-drawn "ASCENSORE" wordmark, in white for the dark background.
class AppLogo extends StatelessWidget {
  final double height;

  const AppLogo({super.key, this.height = 44});

  @override
  Widget build(BuildContext context) {
    // The artwork is black lettering with a light outline: inverted, the letters turn white and the
    // outline dark, which reads cleanly on the night-blue background
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -1, 0, 0, 0, 255, //
        0, -1, 0, 0, 255, //
        0, 0, -1, 0, 255, //
        0, 0, 0, 1, 0, //
      ]),
      child: Image.asset('assets/brand/logo.png', height: height, semanticLabel: 'Ascensore'),
    );
  }
}

/// Small rounded label with an icon, for scores, bets and tricks.
class StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final String? tooltip;

  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    this.color = AppColors.textSecondary,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// Keeps forms and menus readable on wide screens.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentWidth({super.key, required this.child, this.maxWidth = 440});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}

/// Gives [child], a column with spacers, at least the height of the screen, and lets it scroll when it needs
/// more: on short screens (small phones, landscape) the spacers shrink to nothing instead of the content
/// overflowing.
class FillOrScroll extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const FillOrScroll({super.key, required this.child, this.maxWidth = 440, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ContentWidth(
          maxWidth: maxWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            // Measures the column at its real width, so the spacers get exactly the height left over
            child: IntrinsicHeight(child: Padding(padding: padding, child: child)),
          ),
        ),
      ),
    );
  }
}

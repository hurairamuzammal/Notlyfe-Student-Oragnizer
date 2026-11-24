import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';

/// Motion tokens respecting reduced-motion accessibility settings.
class M3ExpressiveMotion {
  M3ExpressiveMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 280);
  static const Duration gentle = Duration(milliseconds: 360);
  static const Curve emphasized = Curves.easeOutCubic;

  static Duration resolve(BuildContext context, Duration target) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : target;
  }
}

/// Material 3 Expressive shape-morphing button: rests as a soft pill (28dp)
/// and morphs smoothly into a tactile squircle (12dp) when pressed or selected.
class M3MorphingPillButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget label;
  final IconData? icon;
  final bool selected;
  final bool tonal;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry padding;

  const M3MorphingPillButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.selected = false,
    this.tonal = false,
    this.backgroundColor,
    this.foregroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  @override
  State<M3MorphingPillButton> createState() => _M3MorphingPillButtonState();
}

class _M3MorphingPillButtonState extends State<M3MorphingPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final enabled = widget.onPressed != null;

    final bg = widget.backgroundColor ??
        (widget.selected
            ? cs.primary
            : (widget.tonal ? cs.secondaryContainer : cs.primaryContainer));
    final fg = widget.foregroundColor ??
        (widget.selected
            ? cs.onPrimary
            : (widget.tonal ? cs.onSecondaryContainer : cs.onPrimaryContainer));

    final radius = (_pressed || widget.selected) ? 14.0 : 28.0;
    final dur = M3ExpressiveMotion.resolve(context, M3ExpressiveMotion.fast);

    return AnimatedScale(
      scale: _pressed ? 0.965 : 1.0,
      duration: dur,
      curve: M3ExpressiveMotion.emphasized,
      child: AnimatedContainer(
        duration: dur,
        curve: M3ExpressiveMotion.emphasized,
        decoration: BoxDecoration(
          color: enabled ? bg : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            splashFactory: InkSparkle.splashFactory,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel:
                enabled ? () => setState(() => _pressed = false) : null,
            onTap: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    widget.onPressed!();
                  }
                : null,
            child: Padding(
              padding: widget.padding,
              child: IconTheme(
                data: IconThemeData(
                  color: enabled ? fg : cs.onSurface.withValues(alpha: 0.38),
                  size: 18,
                ),
                child: DefaultTextStyle(
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: enabled ? fg : cs.onSurface.withValues(alpha: 0.38),
                    fontWeight: FontWeight.w700,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon),
                        const SizedBox(width: 8),
                      ],
                      widget.label,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Expressive filter chip that morphs between pill (unselected) and squircle (selected).
class M3MorphingFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;
  final IconData? icon;

  const M3MorphingFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dur = M3ExpressiveMotion.resolve(context, M3ExpressiveMotion.fast);
    final radius = selected ? 12.0 : 24.0;
    final activeBg = accentColor?.withValues(alpha: 0.22) ?? cs.primaryContainer;
    final activeBorder = accentColor ?? cs.primary;
    final activeFg = selected ? cs.onSurface : cs.onSurfaceVariant;

    return AnimatedContainer(
      duration: dur,
      curve: M3ExpressiveMotion.emphasized,
      decoration: BoxDecoration(
        color: selected ? activeBg : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: selected
              ? activeBorder.withValues(alpha: 0.85)
              : cs.outlineVariant.withValues(alpha: 0.4),
          width: selected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          splashFactory: InkSparkle.splashFactory,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? activeBorder : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                ] else if (selected) ...[
                  Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: activeBorder,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: activeFg,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Morphing icon button (circle when idle -> soft squircle on press/active).
class M3ExpressiveIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final Color? color;
  final Color? backgroundColor;

  const M3ExpressiveIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.color,
    this.backgroundColor,
  });

  @override
  State<M3ExpressiveIconButton> createState() =>
      _M3ExpressiveIconButtonState();
}

class _M3ExpressiveIconButtonState extends State<M3ExpressiveIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dur = M3ExpressiveMotion.resolve(context, M3ExpressiveMotion.fast);
    final radius = (_pressed || widget.active) ? 12.0 : 22.0;
    final bg = widget.backgroundColor ??
        (widget.active
            ? cs.primaryContainer
            : cs.surfaceContainerHighest.withValues(alpha: 0.55));
    final fg =
        widget.color ?? (widget.active ? cs.primary : cs.onSurfaceVariant);

    return Tooltip(
      message: widget.tooltip,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: dur,
        curve: M3ExpressiveMotion.emphasized,
        child: AnimatedContainer(
          duration: dur,
          curve: M3ExpressiveMotion.emphasized,
          constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              splashFactory: InkSparkle.splashFactory,
              onTapDown: widget.onPressed != null
                  ? (_) => setState(() => _pressed = true)
                  : null,
              onTapUp: widget.onPressed != null
                  ? (_) => setState(() => _pressed = false)
                  : null,
              onTapCancel: widget.onPressed != null
                  ? () => setState(() => _pressed = false)
                  : null,
              onTap: widget.onPressed,
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(widget.icon, size: 20, color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared uppercase Material 3 section header.
class M3SectionHeader extends StatelessWidget {
  final String title;
  const M3SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Shared Material 3 grouped settings container card.
class M3SettingsGroupCard extends StatelessWidget {
  final List<Widget> children;
  final double borderRadius;

  const M3SettingsGroupCard({
    super.key,
    required this.children,
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Column(children: children),
    );
  }
}

/// Shared Material 3 rounded squircle icon badge.
class M3IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final EdgeInsetsGeometry padding;

  const M3IconBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = 22,
    this.padding = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: effectiveColor, size: size),
    );
  }
}

/// Shared Material 3 Expressive confirmation dialog.
Future<bool> showM3ConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            if (icon != null) ...[
              M3IconBadge(
                icon: icon,
                color: destructive ? cs.error : cs.primary,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  )
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Controller for updating a live [M3TransferProgressDialog].
class M3TransferProgressController {
  double progress = 0.0;
  String bytesText = '';
  String speedText = '';
  StateSetter? _setState;

  void detach() {
    _setState = null;
  }

  void update({
    required int transferred,
    required int total,
    required double speedBytesPerSec,
    String fallbackVerb = 'Transferring...',
  }) {
    final safeTotal = total > 0 ? total : 0;
    progress = safeTotal > 0 ? (transferred / safeTotal).clamp(0.0, 1.0) : 0.0;
    final recMb = (transferred / (1024 * 1024)).toStringAsFixed(1);
    final totMb =
        safeTotal > 0 ? (safeTotal / (1024 * 1024)).toStringAsFixed(1) : '?';
    final pct =
        safeTotal > 0 ? ' (${(progress * 100).toStringAsFixed(0)}%)' : '';
    bytesText = '$recMb / $totMb MB$pct';
    if (speedBytesPerSec > 1024 * 1024) {
      speedText =
          '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (speedBytesPerSec > 0) {
      speedText = '${(speedBytesPerSec / 1024).toStringAsFixed(0)} KB/s';
    } else {
      speedText = fallbackVerb;
    }
    try {
      _setState?.call(() {});
    } catch (_) {
      _setState = null;
    }
  }
}

/// Shows a Material 3 Expressive upload/download progress dialog bound to [controller].
void showM3TransferProgressDialog(
  BuildContext context, {
  required String fileName,
  required IconData icon,
  required M3TransferProgressController controller,
  String initialStatus = 'Starting...',
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      final theme = Theme.of(dialogCtx);
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          controller._setState = setModalState;
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            contentPadding: const EdgeInsets.all(22),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    M3IconBadge(icon: icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const M3ShapeChangingProgressIndicator(
                      size: 20,
                      strokeWidth: 2.2,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: controller.progress > 0 ? controller.progress : null,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      controller.bytesText.isNotEmpty
                          ? controller.bytesText
                          : initialStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      controller.speedText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  ).whenComplete(controller.detach);
}

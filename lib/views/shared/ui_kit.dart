import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Small, reusable presentation atoms shared across the storefront and admin.

/// An uppercase gold "eyebrow" over a serif heading.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.eyebrow,
    this.align = TextAlign.left,
    this.onInk = false,
  });

  final String title;
  final String? eyebrow;
  final TextAlign align;
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    final cross = align == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: cross,
      children: [
        if (eyebrow != null) ...[
          Text(eyebrow!.toUpperCase(), style: AppTypography.eyebrow()),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(
          title,
          textAlign: align,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: onInk ? AppColors.textOnInk : AppColors.ink,
          ),
        ),
      ],
    );
  }
}

/// Primary filled action, ink by default.
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.gold = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool loading;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(label),
            ],
          );

    final button = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: gold
          ? ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              disabledBackgroundColor: AppColors.goldSoft,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(AppSpacing.rSm),
              ),
            )
          : null,
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Coloured stock indicator with a dot.
class StockBadge extends StatelessWidget {
  const StockBadge({
    super.key,
    required this.stock,
    this.threshold = 5,
    this.compact = false,
  });

  final int stock;
  final int threshold;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String label;
    if (stock <= 0) {
      color = AppColors.outOfStock;
      label = 'Sold out';
    } else if (stock <= threshold) {
      color = AppColors.lowStock;
      label = compact ? '$stock left' : 'Only $stock left';
    } else {
      color = AppColors.inStock;
      label = 'In stock';
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// +/- quantity stepper with a max bound.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.max,
  });

  final int value;
  final int? max;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final atMax = max != null && value >= max!;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: const BorderRadius.all(AppSpacing.rSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove, value > 1 ? onDecrement : null),
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _btn(Icons.add, atMax ? null : onIncrement),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Icon(
        icon,
        size: 18,
        color: onTap == null ? AppColors.mist : AppColors.ink,
      ),
    ),
  );
}

/// A network image with a graceful placeholder/error, tuned for CDN .webp.
class VfImage extends StatelessWidget {
  const VfImage({
    super.key,
    this.url,
    this.fit = BoxFit.cover,
    this.aspectRatio,
  });

  final String? url;
  final BoxFit fit;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (url == null || url!.isEmpty) {
      image = _placeholder();
    } else {
      image = CachedNetworkImage(
        imageUrl: url!,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) =>
            _placeholder(icon: Icons.checkroom_outlined),
      );
    }
    if (aspectRatio != null) {
      return AspectRatio(aspectRatio: aspectRatio!, child: image);
    }
    return image;
  }

  Widget _placeholder({IconData icon = Icons.image_outlined}) => Container(
    color: AppColors.surfaceAlt,
    alignment: Alignment.center,
    child: Icon(icon, color: AppColors.mist, size: 32),
  );
}

/// Centered empty/placeholder state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.mist),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A small colour swatch used in variant pickers and product cards.
/// Named `VfSwatch` to avoid clashing with Flutter's `ColorSwatch`.
class VfSwatch extends StatelessWidget {
  const VfSwatch({
    super.key,
    required this.hex,
    this.selected = false,
    this.size = 28,
    this.onTap,
    this.disabled = false,
  });

  final String? hex;
  final bool selected;
  final double size;
  final VoidCallback? onTap;
  final bool disabled;

  Color get _color {
    final h = hex?.replaceFirst('#', '');
    if (h == null || h.length != 6) return AppColors.mist;
    final value = int.tryParse('FF$h', radix: 16);
    return value == null ? AppColors.mist : Color(value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: size + 8,
        height: size + 8,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.ink : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.line),
          ),
          child: disabled
              ? const Icon(Icons.close, size: 14, color: Colors.white70)
              : null,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lexhub/core/theme/app_dimens.dart';

/// Content-sized catalog rows: long translations never rely on aspect ratios.
class AdaptiveCardList extends StatelessWidget {
  const AdaptiveCardList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
          final columns = constraints.maxWidth / scale >= 760 ? 2 : 1;
          return ListView.separated(
            padding: padding,
            itemCount: (itemCount / columns).ceil(),
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
            itemBuilder: (context, row) => IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: row * columns + col < itemCount
                          ? itemBuilder(context, row * columns + col)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
}

/// HOLAT YORLIG'I (badge) — tintli fon + KONTRASTLI matn.
///
/// NIMA UCHUN ALOHIDA WIDGET: bu naqsh loyihada 30+ joyda qo'lda qurilgan va
/// har birida matn rangi AKSENTNING O'ZIDA yozilgan — o'lchov 2.10:1 gacha
/// tushgan (talab 4.5:1). Yorliqni bitta joyda qurish nuqsonni takrorlanishdan
/// TO'XTATADI: rang tanlash `AppTone` ga topshiriladi va u o'lchangan.
///
/// SHRIFT: 11 px dan past TUSHMAYDI. `fontSize: 10` yorliqlar `textScaleFactor`
/// 1.0 da ham chegaraviy o'qiladi va 1.3 da qatorga sig'maydi.
///
/// SEMANTIKA: bu widget bosiladigan emas — `Semantics(button: true)` BERMAYDI.
/// Ekran o'quvchi uni oddiy matn sifatida o'qiydi, bu to'g'ri xatti-harakat.
library;

import 'package:flutter/material.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/tone.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.dense = false,
  });

  /// Yorliq matni. l10n'dan keladi — bu yerda literal YOZILMAYDI.
  final String label;

  /// Semantik rang jufti (`AppTone.success`, `AppTone.danger`, ...).
  final AppTone tone;

  /// Ixtiyoriy ikonka. Matn bilan BIR XIL rangda bo'ladi.
  final IconData? icon;

  /// Zich variant — ro'yxat elementi ichida joy tor bo'lganda.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onTint = tone.on(isDark);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.xs : AppSpacing.sm,
        vertical: dense ? 2 : AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: tone.bg(isDark),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: tone.border(isDark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 11 : AppIconSize.xs, color: onTint),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: onTint,
            ),
          ),
        ],
      ),
    );
  }
}

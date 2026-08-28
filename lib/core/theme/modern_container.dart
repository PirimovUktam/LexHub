/// KARTA QOBIG'I — loyihadagi barcha kartochkalarning YAGONA yuzasi.
///
/// NIMA UCHUN BU FAYLNI YAXSHILASH ENG SAMARALI: `ModernContainer` 40+ joyda
/// ishlatiladi, ya'ni chuqurlik (soya/hoshiya) va bosish reaksiyasi shu bitta
/// faylda tuzatilsa, hamma ekran bir vaqtda yangilanadi va API o'zgarmaydi
/// (chaqiruvchi kod tegilmaydi — §1 ZERO-BREAKING).
///
/// UCH O'ZGARISH VA SABABLARI:
///
/// 1. SOYA ikki qatlamli bo'ldi (`AppShadows.card`). Bir qatlamli
///    `blurRadius: 16` soya "stikker" effekti berardi — karta fonga
///    yopishgandek. Ikki qatlam (keng ambient + qisqa kontakt) yuzani
///    KO'TARILGAN qiladi.
///
/// 2. QORONG'I mavzuda soya BUTUNLAY olib tashlandi. O'lchov: qora soya
///    `#0A192F` fon ustida ko'rinmaydi (kontrast yo'q) — u faqat GPU vaqtini
///    yeyardi. Chuqurlik endi ichki gradient (`innerSheen`) va yorqinroq
///    hoshiya bilan beriladi.
///
/// 3. BOSISH reaksiyasi qo'shildi. `InkWell` ripple'i to'q kartochkalarda
///    deyarli ko'rinmaydi, shuning uchun `onHighlightChanged` orqali karta
///    ozgina kichrayadi. `onHighlightChanged` ATAYLAB tanlandi: tashqi
///    `GestureDetector` qo'shilsa u `InkWell` bilan gesture arena'da
///    kurashadi va bosish YO'QOLISHI mumkin.
library;

import 'package:flutter/material.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/depth.dart';

class ModernContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final bool hasShadow;
  final VoidCallback? onTap;

  /// Ixtiyoriy aksent "glow" — hero karta va ko'tarilgan yuzalar uchun.
  /// `null` bo'lsa standart karta soyasi ishlatiladi.
  final Color? glowColor;

  const ModernContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius = AppRadius.card,
    this.hasShadow = true,
    this.onTap,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = backgroundColor ?? (isDark ? AppColors.cardDark : AppColors.cardLight);
    final border = borderColor ?? AppBorders.hairline(isDark);

    // Ichki gradient FAQAT to'liq shaffofsiz fonda: tintli (yarim shaffof)
    // fonda gradient alfani o'zgartiradi va o'lchangan kontrastni suradi.
    final bool opaque = bg.a >= 1.0;
    final sheen = opaque ? innerSheen(isDark) : null;

    final decoration = BoxDecoration(
      color: sheen == null ? bg : null,
      gradient: sheen == null
          ? null
          : LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color.lerp(bg, Colors.white, 0.04)!,
                bg,
              ],
            ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: border, width: borderWidth),
      boxShadow: !hasShadow
          ? null
          : glowColor != null
              ? AppShadows.glow(glowColor!, alpha: isDark ? 0.32 : 0.18)
              : AppShadows.card(isDark),
    );

    if (onTap != null) {
      return _PressableCard(
        margin: margin,
        padding: padding,
        decoration: decoration,
        borderRadius: borderRadius,
        onTap: onTap!,
        child: child,
      );
    }

    return Container(
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );
  }
}

/// Bosilganda ozgina kichrayadigan karta.
///
/// `AnimatedScale` `InkWell` USTIDA turadi — pastda bo'lsa ripple ham
/// masshtablanib "sirg'alib ketgan" ko'rinadi.
class _PressableCard extends StatefulWidget {
  const _PressableCard({
    required this.child,
    required this.decoration,
    required this.borderRadius,
    required this.onTap,
    this.padding,
    this.margin,
  });

  final Widget child;
  final BoxDecoration decoration;
  final double borderRadius;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _down ? 0.985 : 1.0,
      duration: AppMotion.of(context, AppMotion.fast),
      curve: AppMotion.curve,
      child: Container(
        margin: widget.margin,
        decoration: widget.decoration,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            onTap: widget.onTap,
            onHighlightChanged: (bool value) {
              if (_down == value) return;
              setState(() => _down = value);
            },
            child: Padding(
              padding: widget.padding ?? EdgeInsets.zero,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

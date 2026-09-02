/// BOSISH REAKSIYASI — bosilganda element ozgina kichrayadi.
///
/// NIMA UCHUN: `InkWell` ripple'i to'q fonli kartochkalarda deyarli
/// ko'rinmaydi (ripple rangi fonga singib ketadi), shuning uchun
/// foydalanuvchi bosish qabul qilinganini SEZMAYDI. Scale reaksiyasi esa
/// fon rangidan mustaqil.
///
/// ACCESSIBILITY: `reduce motion` yoqilgan bo'lsa `AppMotion.of` davomiylikni
/// nolga tushiradi — animatsiya yo'q, lekin bosish ISHLAYDI.
///
/// SEMANTIKA: bu widget `Semantics(button: true)` bermaydi. Sabab —
/// ostidagi `Text` semantikasi qobiqqa qo'shilib, ekran o'quvchi yorliqni
/// ikki marta o'qishi mumkin. Semantikani chaqiruvchi joy o'zi beradi
/// (`lex_bottom_nav.dart` dagi izohga qara).
library;

import 'package:flutter/material.dart';
import 'package:lexhub/core/theme/app_dimens.dart';

class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Bosilgandagi o'lcham. 0.97 — sezilarli, lekin "sakramaydi".
  /// 0.90 dan past qiymat matnni bir lahzaga o'qilmas qiladi.
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down && enabled ? widget.scale : 1.0,
        duration: AppMotion.of(context, AppMotion.fast),
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}

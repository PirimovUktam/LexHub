/// EKRANGA KIRISH ANIMATSIYASI — pastdan yuqoriga siljish + paydo bo'lish.
///
/// NIMA UCHUN: mazmun bir zumda "paydo bo'lib qolsa", foydalanuvchi ko'zi
/// qayerga qarashini bilmaydi. Navbat bilan chiqish esa o'qish tartibini
/// KO'RSATADI (yuqoridan pastga).
///
/// QAT'IY CHEKLOV — `ListView.builder` DA ISHLATILMAYDI. Sabab: builder
/// elementni qayta ishlatganda `initState` yana chaqiriladi va skroll
/// paytida element qaytadan "sakrab" chiqadi. Faqat statik `Column` yoki
/// ekranning birinchi ko'rinishi uchun.
///
/// ACCESSIBILITY: `reduce motion` da davomiylik nolga tushadi — mazmun
/// darhol, siljishsiz ko'rinadi (yo'qolib ketmaydi).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lexhub/core/theme/app_dimens.dart';

class EntranceFade extends StatefulWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.index = 0,
    this.offsetY = 16,
  });

  final Widget child;

  /// Navbat raqami — kechikish `index * AppMotion.stagger`.
  /// 6 dan katta indeks kechikishni sezilarli qiladi, shuning uchun
  /// kechikish 6 ta qadamda to'xtaydi.
  final int index;

  /// Boshlang'ich siljish (px). 24 dan katta qiymat "uloqtirilgan"
  /// ko'rinadi va katta shrift masshtabida layout sakrashini beradi.
  final double offsetY;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: AppMotion.curve);

  bool _started = false;
  Timer? _delay;

  /// NIMA UCHUN `didChangeDependencies`, `initState` EMAS: `MediaQuery`
  /// o'qilishi inherited widget'ga bog'lanish hisoblanadi va `initState` da
  /// bu assertion bilan yiqiladi.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final duration = AppMotion.of(context, AppMotion.slow);
    _c.duration = duration;

    // `reduce motion`: mazmun DARHOL o'z joyida ko'rinadi — yashirin qolmaydi.
    if (duration == Duration.zero) {
      _c.value = 1;
      return;
    }

    final delay = AppMotion.stagger * widget.index.clamp(0, 6);
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      _delay = Timer(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (BuildContext context, Widget? _) {
        final double v = _t.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * widget.offsetY),
            child: widget.child,
          ),
        );
      },
    );
  }
}

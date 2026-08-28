/// FAVQULODDA HUQUQIY YORDAM BANNERI.
///
/// NIMA UCHUN TO'LDIRILGAN QIZIL: ilgari banner OCHIQ pushti fon + qizil
/// matn edi va bosh sahifadagi boshqa yumshoq kartalar orasida yo'qolib
/// ketardi. Favqulodda holat (hibsga olish, tekshiruv, majburiy so'roq)
/// vaqtida foydalanuvchi ekranga SEKUNDLARDA qaraydi — shuning uchun bu
/// yagona to'liq to'ldirilgan (high-emphasis) element.
///
/// PULS: qalqon ikonkasi atrofidagi yorug'lik `AppMotion.pulse` (1600 ms)
/// bilan sekin nafas oladi. NIMA UCHUN aynan shu element: puls faqat ALFA
/// va `BoxShadow` ni o'zgartiradi — hech qanday o'lcham yoki joylashuv
/// o'zgarmaydi, ya'ni har kadrda qayta layout QILINMAYDI. `RepaintBoundary`
/// esa qayta chizishni shu kichik maydon bilan cheklaydi.
///
/// ACCESSIBILITY: puls TAKRORLANUVCHI animatsiya — `reduce motion` yoqilgan
/// bo'lsa umuman ishga tushmaydi (`AppMotion.loopAllowed`). Bu holatda ikonka
/// eng yorqin (to'liq ko'rinadigan) holatida QOLADI, ya'ni ma'lumot
/// yo'qolmaydi.
///
/// "SOS" literali ATAYLAB kodda qoldirildi — `no_hardcoded_ui_strings_test`
/// dagi `_widgetAllowed` ro'yxati unga tayanadi va ro'yxat eskirsa alohida
/// test yiqiladi.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/features/emergency_rights/presentation/pages/emergency_rights_page.dart';

class EmergencyQuickButton extends StatefulWidget {
  const EmergencyQuickButton({super.key});

  @override
  State<EmergencyQuickButton> createState() => _EmergencyQuickButtonState();
}

class _EmergencyQuickButtonState extends State<EmergencyQuickButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Semantics(
      button: true,
      // `label:` YO'Q: ichida sarlavha, "SOS" va tavsif matnlari bor —
      // tashqi yorliq berilsa sarlavha ikki marta o'qilardi. Bolalar
      // semantikasi qo'shilib tabiiy o'qiladi: sarlavha, SOS, tavsif.
      child: AnimatedScale(
        scale: _down ? 0.985 : 1.0,
        duration: AppMotion.of(context, AppMotion.fast),
        curve: AppMotion.curve,
        child: Material(
          borderRadius: BorderRadius.circular(AppRadius.card),
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onHighlightChanged: (bool value) {
              if (_down == value) return;
              setState(() => _down = value);
            },
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmergencyRightsPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  // O'LCHANGAN TUZATISH: ilgari gradient `crimsonDark` →
                  // `emergency` (#EF4444) edi va O'NG YARMIDA oq matn 3.76:1
                  // kontrast berardi — WCAG AA (4.5:1) dan past. Endi ikki
                  // uchi ham AA'dan o'tadi: #B91C1C 6.47:1, #DC2626 4.83:1.
                  colors: [AppColors.emergencyStrong, AppColors.crimsonDark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emergency.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const _PulsingShield(),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.emergencyQuickTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Gap(AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xs),
                              ),
                              child: const Text(
                                // §16: "SOS" — XALQARO belgi, ikki tilda ham
                                // bir xil. ARB'ga kalit qo'shish faqat shovqin
                                // bo'lardi: `uz` va `en` qiymati aynan bir xil
                                // bo'lar edi. Yonidagi sarlavha
                                // (`emergencyQuickTitle`) esa tarjimalanadi.
                                "SOS",
                                style: TextStyle(
                                  color: AppColors.crimsonDark,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Gap(2),
                        Text(
                          l10n.emergencyQuickSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(AppSpacing.xxs),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: AppIconSize.md,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
/// Sekin "nafas oladigan" qalqon ikonkasi.
///
/// FAQAT ALFA VA SOYA o'zgaradi — o'lcham o'zgarmaydi. Sabab: `Row` ichida
/// o'lchamni animatsiya qilish har kadrda qo'shni matn blokini qayta
/// o'lchashga majbur qiladi va uzun sarlavhada matn "sakraydi".
class _PulsingShield extends StatefulWidget {
  const _PulsingShield();

  @override
  State<_PulsingShield> createState() => _PulsingShieldState();
}

class _PulsingShieldState extends State<_PulsingShield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.pulse,
  );

  bool _configured = false;

  /// `MediaQuery` o'qilishi inherited widget'ga bog'lanish hisoblanadi —
  /// `initState` da bu assertion bilan yiqiladi.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    if (AppMotion.loopAllowed(context)) {
      _c.repeat(reverse: true);
    } else {
      // Puls yo'q: ikonka ENG KO'RINADIGAN holatida qoladi.
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? child) {
          final double t = Curves.easeInOut.transform(_c.value);
          return Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14 + 0.16 * t),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.18 * t),
                  blurRadius: 6 + 10 * t,
                  spreadRadius: 2 * t,
                ),
              ],
            ),
            child: child,
          );
        },
        // `child` AnimatedBuilder tashqarisida — har kadrda qayta
        // QURILMAYDI.
        child: const Icon(
          Icons.shield_rounded,
          color: Colors.white,
          size: AppIconSize.md,
        ),
      ),
    );
  }
}

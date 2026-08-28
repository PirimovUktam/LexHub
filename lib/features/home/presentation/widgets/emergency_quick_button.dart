/// FAVQULODDA HUQUQIY YORDAM BANNERI.
///
/// NIMA UCHUN TO'LDIRILGAN QIZIL: ilgari banner OCHIQ pushti fon + qizil
/// matn edi va bosh sahifadagi boshqa yumshoq kartalar orasida yo'qolib
/// ketardi. Favqulodda holat (hibsga olish, tekshiruv, majburiy so'roq)
/// vaqtida foydalanuvchi ekranga SEKUNDLARDA qaraydi — shuning uchun bu
/// yagona to'liq to'ldirilgan (high-emphasis) element.
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

class EmergencyQuickButton extends StatelessWidget {
  const EmergencyQuickButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Semantics(
      button: true,
      // `label:` YO'Q: ichida sarlavha, "SOS" va tavsif matnlari bor —
      // tashqi yorliq berilsa sarlavha ikki marta o'qilardi. Bolalar
      // semantikasi qo'shilib tabiiy o'qiladi: sarlavha, SOS, tavsif.
      child: Material(
        borderRadius: BorderRadius.circular(AppRadius.card),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
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
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: AppIconSize.md,
                  ),
                ),
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
    );
  }
}

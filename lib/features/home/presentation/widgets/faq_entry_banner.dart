/// FAQ (ko'p beriladigan savollar) BANNERI — bosh sahifadagi kirish nuqtasi.
///
/// UCH O'ZGARISH VA SABABLARI:
///
/// 1. XOM O'LCHAMLAR TOKENGA KO'CHIRILDI. Fayl ichida `14`, `11`, `6`, `8`
///    kabi qo'lda yozilgan `padding`/`radius` va `13.5`, `11.5`, `9.5` kabi
///    KASRLI shrift o'lchamlari bor edi. Kasrli o'lcham hech qanday shkalada
///    yo'q va past DPI ekranda yarim piksel yumaloqlanib matnni xiralashtiradi;
///    qo'lda yozilgan `padding` esa shu bannerni qo'shni kartalar bilan
///    bir chizuvda turmasligiga olib kelardi.
///
/// 2. IKKI CHIP `AppTone` GA O'TDI. Ilgari yashil "TOP" chipi va sariq
///    "Barchasi" chipi matn rangi sifatida AKSENTNING O'ZINI ishlatardi
///    (`emeraldDark`, `amberDark`). `AppTone` esa tint ustida O'LCHANGAN matn
///    rangini beradi (`tone.dart` izohiga qara) — kod-rang saqlanadi, o'qilishi
///    esa isbotlangan. Yashil chip endi umuman qo'lda qurilmaydi:
///    `StatusBadge(tone: AppTone.success)`.
///
/// 3. IKONKA RANGI O'LCHANDI. Chiroq ikonkasi `amber` (#F59E0B) edi va
///    `amberLight` (#FEF3C7) fon ustida 1.93:1 berardi — WCAG 1.4.11 (3:1)
///    dan PAST. Endi `AppTone.warning.on()` (#92400E, min 5.86:1). Ikonka
///    ma'no tashimasa ham (ayni ma'no yonidagi sarlavhada bor) bu tuzatish
///    BEPUL: yangi token talab qilmaydi.
///
/// O'ZGARMAGAN: `ModernContainer` bosish reaksiyasini o'zi beradi
/// (`_PressableCard`), navigatsiya `FaqQuestionsPage` ga o'zgarishsiz boradi.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/status_badge.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/home/presentation/pages/faq_questions_page.dart';

class FaqEntryBanner extends StatelessWidget {
  const FaqEntryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    const AppTone tone = AppTone.warning;

    return ModernContainer(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FaqQuestionsPage(),
          ),
        );
      },
      padding: const EdgeInsets.all(AppSpacing.lg),
      // `backgroundColor` BERILMAYDI: `ModernContainer` standarti aynan
      // `cardLight` (#FFFFFF) / `cardDark` — qo'lda takrorlash faqat
      // ikki xil bo'lib ketish xavfini qo'shardi.
      borderColor: tone.accent(isDark).withValues(alpha: 0.30),
      borderWidth: 1.2,
      child: Row(
        children: [
          Container(
            // 12 + 22 + 12 = 46 px — ilgarigi 11 + 24 + 11 = 46 bilan AYNI
            // o'lchamda qoladi, ya'ni qator balandligi siljimaydi.
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: tone.bg(isDark),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.lightbulb_rounded,
              color: tone.on(isDark),
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
                    // O'LCHANGAN DEFEKT (Pixel 9, 1080x2424, density 420,
                    // 2026-08-26): bu `Row` "A RenderFlex overflowed by 16
                    // pixels on the right" bergan va Bosh sahifada sariq-qora
                    // chiziqli marker bilan "TOP 100+" chipi KESILGAN holda
                    // ko'ringan. Sabab: sarlavha `Text` cheksiz kenglik
                    // so'ragan (`Flexible` yo'q edi), yonidagi chip esa
                    // o'zining tabiiy kengligini talab qilgan.
                    //
                    // `Flexible` + `ellipsis` locale'dan MUSTAQIL yechim:
                    // `en` sarlavhasi ("Frequently asked questions")
                    // o'zbekchasidan uzunroq, shuning uchun qat'iy o'lcham
                    // yoki `SizedBox` bilan "tuzatish" boshqa tilda yana
                    // yiqilardi.
                    Flexible(
                      child: Text(
                        l10n.faqBannerTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    StatusBadge(
                      label: l10n.faqBannerBadge,
                      tone: AppTone.success,
                      dense: true,
                    ),
                  ],
                ),
                const Gap(2),
                Text(
                  l10n.faqBannerSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: tone.bg(isDark),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.categoryAll,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tone.on(isDark),
                  ),
                ),
                const Gap(2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: AppIconSize.xs,
                  color: tone.on(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

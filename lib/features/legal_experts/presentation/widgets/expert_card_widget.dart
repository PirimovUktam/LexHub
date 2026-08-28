import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/expert_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/status_badge.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/expert_profile_modal.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/expert_rating_stars.dart';

/// Advokat kartasi.
///
/// §6: bo'sh maydon uchun TO'QIMA qiymat ko'rsatilmaydi — baho/tajriba/
/// yutuqlar chip'lari faqat REAL raqam bo'lganda chiqadi, bo'sh bio esa
/// umuman render qilinmaydi.
///
/// ── BATCH 4 (dizayn brifi §4) — TUZATISHLAR ──
///
/// 1. QO'LDA QURILGAN `_metricChip` O'CHIRILDI. U fon va matn rangini
///    CHAQIRUVCHIDAN olardi, ya'ni har bir chaqiruv joyida kontrast qaytadan
///    "qo'lda" tanlanardi — va uchtasidan ikkitasi AA'ni buzgan edi:
///      • baho chip'i `amberDark` (#D97706) `amberLight` ustida 2.86:1;
///      • yutilgan ish `emeraldDark` (#059669) `emeraldLight` ustida 3.32:1.
///    Endi `StatusBadge` — fon, chegara va matn rangi AYNI `AppTone` dan
///    keladi va 11 px shrift poli qulflangan.
///
/// 2. "TASDIQLANGAN" BELGISI 10 px edi (loyihadagi 11 px polidan past) va
///    `emeraldDark`+`emeraldLight` = 3.32:1 berardi. Endi `AppTone.info`
///    (lex.uz ishonch ko'ki, 5.61:1 / 5.44:1) — ishonch belgisi yutuq
///    belgisidan RANG bilan ham ajraladi.
///
/// 3. BAHO endi chip EMAS, `ExpertRatingStars` — beshta yulduz + raqam +
///    baholar soni. Yulduzlar `AppTone.warning.on()` da (5.86:1 / 7.07:1);
///    `reviewsCount == 0` bo'lsa qator UMUMAN chizilmaydi (§6).
///
/// 4. "Bog'lanish" yorlig'i qorong'ida `indigo` edi — `cardDark` ustida
///    3.27:1, 12 px qalin MATN uchun 4.5:1 kerak. Endi
///    `AppTone.accentIndigo.on()`: 4.67:1 / 5.91:1.
///
/// 5. AVATAR qorong'ida `indigo` fon + OQ harf = 4.47:1 edi. Endi
///    `indigoOnDark` fon + `primary` harf = 5.98:1 (qirra `cardDark` ga
///    nisbatan 4.90:1) — `action_steps_timeline.dart` bilan AYNI qoida.
class ExpertCardWidget extends StatelessWidget {
  final LegalExpert expert;

  const ExpertCardWidget({super.key, required this.expert});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final bio = expert.bio.trim();
    final city = expert.city.trim();

    final metricChips = <Widget>[
      if (expert.experienceYears > 0)
        StatusBadge(
          label: l10n.expertExperienceYears(expert.experienceYears),
          tone: AppTone.brand,
          icon: Icons.workspace_premium_outlined,
          dense: true,
        ),
      if (expert.successfulCasesCount > 0)
        StatusBadge(
          label: l10n.expertWonCases(expert.successfulCasesCount),
          tone: AppTone.success,
          icon: Icons.gavel_rounded,
          dense: true,
        ),
    ];

    return ModernContainer(
      onTap: () => ExpertProfileModal.show(context, expert),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar — 5-BAND: qorong'ida yorqin fon + to'q harf.
              CircleAvatar(
                radius: 26,
                backgroundColor:
                    isDark ? AppColors.indigoOnDark : AppColors.primary,
                child: Text(
                  expertAvatarInitial(expert),
                  style: TextStyle(
                    color: isDark ? AppColors.primary : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const Gap(AppSpacing.md),
              // Name & Specialization
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            expertDisplayName(l10n, expert),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 2-BAND: qo'lda qurilgan 10 px belgi → `StatusBadge`.
                        // `isVerified` bazadan keladi (default `false`), ya'ni
                        // bu belgi HECH QACHON o'ylab topilmaydi. "Pro" yoki
                        // "Premium" darajasi UI'da YOZILMAYDI — bazada bunday
                        // maydon YO'Q (§6).
                        if (expert.isVerified) ...[
                          const Gap(AppSpacing.xxs),
                          StatusBadge(
                            label: l10n.expertVerifiedBadge,
                            tone: AppTone.info,
                            icon: Icons.verified_rounded,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                    const Gap(3),
                    Text(
                      expertSpecializationText(l10n, expert),
                      style: TextStyle(
                        color: isDark ? AppColors.textMutedDark : AppColors.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Hudud faqat bazada bo'lsa ko'rsatiladi (to'qima
                    // "Toshkent sh." endi YO'Q).
                    if (city.isNotEmpty) ...[
                      const Gap(2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                          const Gap(AppSpacing.xxs),
                          Text(
                            city,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // 3-BAND: BAHO — yulduzlar + raqam + baholar soni. `reviewsCount`
          // 0 bo'lsa `ExpertRatingStars` ning O'ZI bo'sh qaytaradi, ya'ni
          // baholanmagan advokat "0.0 ☆☆☆☆☆" ko'rinmaydi (§6).
          if (expert.reviewsCount > 0) ...[
            const Gap(AppSpacing.md),
            ExpertRatingStars(
              rating: expert.rating,
              reviewsCount: expert.reviewsCount,
              dense: true,
            ),
          ],

          // METRIK CHIP'LAR — FAQAT REAL raqamlar bilan (§6):
          // tajriba / yutilgan ish 0 bo'lsa chiqmaydi.
          // `Wrap`: inglizcha yorliqlar uzunroq, `Row` da overflow berardi.
          if (metricChips.isNotEmpty) ...[
            const Gap(AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: metricChips,
            ),
          ],

          // Bio snippet (bo'sh bo'lsa render qilinmaydi)
          if (bio.isNotEmpty) ...[
            const Gap(AppSpacing.md),
            Text(
              bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
          ],

          const Gap(AppSpacing.md),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  expertPriceText(l10n, expert),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                  ),
                ),
              ),
              const Gap(AppSpacing.sm),
              Row(
                children: [
                  Text(
                    l10n.expertContact,
                    // 4-BAND: qorong'ida `indigo` 3.27:1 edi.
                    style: TextStyle(
                      color: AppTone.accentIndigo.on(isDark),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(AppSpacing.xxs),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: AppIconSize.xs,
                    color: AppTone.accentIndigo.on(isDark),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

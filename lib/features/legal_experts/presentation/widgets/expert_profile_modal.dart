import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/expert_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/depth.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/consultations/presentation/pages/book_consultation_page.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/expert_rating_stars.dart';
import 'package:url_launcher/url_launcher.dart';

/// Advokat profili (bottom sheet).
///
/// §6: bo'sh maydonlar TO'QIMA qiymat bilan to'ldirilmaydi — litsenziya,
/// manzil, bio va aloqa tugmalari faqat bazada REAL qiymat bo'lganda
/// ko'rsatiladi. "Maslahat turi" satri butunlay olib tashlandi: bu ustun
/// `public_expert_profiles_view` da yo'q, ya'ni u har doim hardcoded
/// `ConsultationType.all` ("Barcha turlar") — bazada tasdiqlanmagan da'vo.
///
/// ── BATCH 4 (dizayn brifi §2.1) — SHISHA EFFEKTI VA KONTRAST ──
///
/// SHISHA EFFEKTI AYNAN SHU YERDA HAQIQIY: bottom sheet kontent USTIGA
/// chiqadi, ya'ni `BackdropFilter` ostida yuvish uchun real piksellar bor
/// (pastki navigatsiyada esa `Scaffold.extendBody` = `false` bo'lgani uchun
/// panel ostida kontent YO'Q — u yerda blur qo'shilmadi).
///
/// ALFA 0.90 — O'LCHOVGA ASOSLANGAN. Shaffof yuza ustidagi matn kontrasti
/// OSTIDAGI kontentga bog'liq, shuning uchun eng yomon ostki qatlam (mutlaq
/// oq VA mutlaq qora) bilan o'lchandi:
///   • yorug' mavzu: asosiy matn 13.62:1, `textSecondaryLight` 5.78:1,
///     `emeraldStrong` 5.86:1, `lexBlueStrong` 5.77:1, `amberOnTint` 5.41:1;
///   • qorong'i mavzu: `textSecondaryDark` 8.98:1, `emeraldOnDark` 6.94:1,
///     `lexBlueOnDark` 6.23:1, `amberOnTintDark` 9.25:1.
/// `textMuted*` shisha ostida AA'ni BUZADI (yorug'da 3.46–3.98:1), shuning
/// uchun modal ichidagi ikkinchi darajali matnlar `textSecondary*` ga
/// ko'chirildi.
///
/// TUZATILGAN KONTRAST NUQSONLARI (hammasi o'lchangan, shishasiz ham past edi):
///   1. "Qo'ng'iroq" tugmasi matni `emerald` yorug' fonda 2.42:1 → `AppTone
///      .success.on()` 7.34:1.
///   2. "Telegram" matni `lexBlue` 3.91:1 (yorug') / 4.30:1 (qorong'i) →
///      `AppTone.info.on()` 7.23:1 / 8.22:1.
///   3. Narx `amberDark` oq karta ustida 3.19:1 → `AppTone.warning.on()`
///      7.09:1 / 10.15:1.
///   4. Metrik blok qiymati qorong'ida `indigo` `cardDark` ustida 3.27:1 →
///      `indigoOnTintDark` 7.34:1.
///   5. Tasdiq belgisi `emeraldDark` yorug' fonda 3.04:1 (grafik polida) va
///      kartadagi belgidan RANGDA farq qilardi → `AppTone.info` (ishonch
///      ko'ki), `expert_card_widget.dart` bilan bir xil.
///   6. Avatar qorong'ida `indigo` fon + OQ harf 4.47:1 → `indigoOnDark` fon
///      + `primary` harf 5.98:1 (qirrasi `backgroundDark` ga 5.90:1).
///   7. "Maslahatga yozilish" tugmasi qorong'ida `indigo` fon + oq matn
///      4.47:1 (16 px qalin matn WCAG "katta matn" EMAS: chegara 18.66 px)
///      → `indigoDark` fon 6.29:1.
///
/// BAHO endi `ExpertRatingStars` (kartadagi AYNI widget). `reviewsCount == 0`
/// bo'lsa yulduz ham, "0.0" ham chizilmaydi — o'rniga `expertNoRating`
/// ("Baho yo'q") matni chiqadi, ya'ni bo'shliq TO'QIMA raqam bilan
/// to'ldirilmaydi (§6).
class ExpertProfileModal extends StatelessWidget {
  final LegalExpert expert;

  const ExpertProfileModal({super.key, required this.expert});

  static void show(BuildContext context, LegalExpert expert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExpertProfileModal(expert: expert),
    );
  }

  Future<void> _callPhone(BuildContext context, String phone) async {
    final l10n = context.l10n;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.expertCallFailed(phone))),
        );
      }
    }
  }

  Future<void> _openTelegram(BuildContext context, String username) async {
    final l10n = context.l10n;
    final uri = Uri.parse("https://t.me/$username");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.expertTelegramFailed(username))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final license = expert.licenseNumber.trim();
    final bio = expert.bio.trim();
    final location = expertLocationText(expert);
    final phone = expert.phoneNumber.trim();
    final telegram = expert.telegramUsername.trim();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => ClipRRect(
        // `ClipRRect` SHART: `BackdropFilter` o'z chegarasidan tashqariga
        // ham yuvishni tarqatadi. Radius yuqoridagi ikki burchakda.
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl + 2),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              // Alfa 0.90 — yuqoridagi o'lchovga qara.
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.90),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl + 2),
              ),
              // Chegara UNIFORM (`Border.all`): bir tomonli `Border` +
              // `borderRadius` Flutter'da paint vaqtida xato beradi
              // (`legal_basis_accordion.dart` da o'lchangan).
              border: Border.all(color: AppBorders.hairline(isDark)),
            ),
            child: Column(
              children: [
                const Gap(AppSpacing.md),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Gap(AppSpacing.md),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                  // Profile Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        // 6-BAND: qorong'ida yorqin fon + to'q harf.
                        backgroundColor:
                            isDark ? AppColors.indigoOnDark : AppColors.primary,
                        child: Text(
                          // Bo'sh ism `substring(0, 1)` da RangeError berardi.
                          expertAvatarInitial(expert),
                          style: TextStyle(
                            color: isDark ? AppColors.primary : Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Gap(AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    expertDisplayName(l10n, expert),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                                // 5-BAND: `emeraldDark` 3.04:1 → ishonch ko'ki
                                // (`expert_card_widget.dart` bilan bir xil).
                                if (expert.isVerified)
                                  Icon(
                                    Icons.verified_rounded,
                                    color: AppTone.info.on(isDark),
                                    size: AppIconSize.sm + 2,
                                  ),
                              ],
                            ),
                            const Gap(AppSpacing.xxs),
                            Text(
                              expertSpecializationText(l10n, expert),
                              style: TextStyle(
                                // Yorug': `primaryLight` 15+:1. Qorong'i:
                                // `indigoLight` #EEF2FF shisha ostida 11.93:1.
                                color: isDark
                                    ? AppColors.indigoLight
                                    : AppColors.primaryLight,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            // Litsenziya FAQAT bazada raqam bo'lsa (§6):
                            // ilgari bo'sh ustun `ADV-VERIFIED` deb ko'rsatilardi.
                            if (license.isNotEmpty) ...[
                              const Gap(AppSpacing.xxs),
                              Text(
                                l10n.expertLicenseLine(license),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  // `textMuted*` shisha ostida 3.46:1 —
                                  // `textSecondary*` ga ko'chirildi.
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Gap(AppSpacing.lg + 2),

                  // BAHO — kartadagi AYNI widget. 0 baho bo'lsa yulduz YO'Q.
                  if (expert.reviewsCount > 0)
                    ExpertRatingStars(
                      rating: expert.rating,
                      reviewsCount: expert.reviewsCount,
                    )
                  else
                    Text(
                      l10n.expertNoRating,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                  const Gap(AppSpacing.md),

                  // METRIK BLOKLAR — TO'QIMA RAQAM YO'Q (§6):
                  // tajriba/yutuq 0 bo'lsa raqam O'YLAB TOPILMAYDI, "—" chiqadi.
                  // Reyting bloki OLIB TASHLANDI: u endi yulduzlar qatorida.
                  Row(
                    children: [
                      _buildMetricBox(
                        title: l10n.expertMetricExperience,
                        value: expert.experienceYears > 0
                            ? l10n.expertMetricYears(expert.experienceYears)
                            : "—",
                        subtitle: l10n.expertMetricPractice,
                        isDark: isDark,
                      ),
                      const Gap(AppSpacing.sm + 2),
                      _buildMetricBox(
                        title: l10n.expertMetricWins,
                        value: expert.successfulCasesCount > 0
                            ? "${expert.successfulCasesCount}+"
                            : "—",
                        subtitle: l10n.expertMetricWonCases,
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const Gap(AppSpacing.lg + 2),

                  // BIO — bo'sh bo'lsa blok UMUMAN render qilinmaydi (§6):
                  // ilgari "Malakali yuridik yordam ko'rsatuvchi advokat."
                  // degan O'YLAB TOPILGAN matn ko'rsatilardi.
                  if (bio.isNotEmpty) ...[
                    ModernContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.expertAboutTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Gap(AppSpacing.sm),
                          Text(
                            bio,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.55,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(AppSpacing.md + 2),
                  ],

                  // MANZIL + NARX. "Maslahat turi: …" satri O'CHIRILDI (§6):
                  // `public_expert_profiles_view` da bunday ustun YO'Q, qiymat
                  // esa har doim hardcoded `ConsultationType.all` bo'lgani
                  // uchun UI bazada yo'q da'voni ko'rsatib turardi.
                  ModernContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shahar/manzil bo'sh bo'lsa satr chiqmaydi — ilgari
                        // "Toshkent sh., Advokatlik byurosi" TO'QIB yozilardi.
                        if (location.isNotEmpty) ...[
                          Row(
                            children: [
                              // Manzil ikonkasi — GRAFIK (3:1 poli):
                              // `crimson` yorug'da 3.76:1, qorong'ida 3.89:1.
                              Icon(Icons.location_on_outlined,
                                  color: AppTone.danger.accent(isDark),
                                  size: AppIconSize.sm + 2),
                              const Gap(AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  location,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Gap(AppSpacing.sm + 2),
                        ],
                        Row(
                          children: [
                            // 3-BAND: narx `amberDark` oq kartada 3.19:1 edi.
                            Icon(
                              Icons.payments_outlined,
                              color: AppTone.warning.on(isDark),
                              size: AppIconSize.sm + 2,
                            ),
                            const Gap(AppSpacing.sm),
                            Expanded(
                              child: Text(
                                expertPriceText(l10n, expert),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTone.warning.on(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Gap(AppSpacing.xl),

                  // Primary Book Consultation Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        BookConsultationPage.show(context, expert);
                      },
                      style: ElevatedButton.styleFrom(
                        // 7-BAND: qorong'ida `indigo` + oq matn 4.47:1 edi;
                        // 16 px qalin matn WCAG "katta matn" EMAS (18.66 px
                        // chegara), ya'ni 4.5:1 kerak. `indigoDark` → 6.29:1.
                        backgroundColor:
                            isDark ? AppColors.indigoDark : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded,
                          size: AppIconSize.sm + 2),
                      label: Text(
                        l10n.expertBookConsultation,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const Gap(AppSpacing.md),

                  // ALOQA TUGMALARI — FAQAT REAL qiymat bo'lganda (§6).
                  // Ilgari bo'sh `phone` ustuni `+998901234567` bilan
                  // to'ldirilardi: foydalanuvchi SOXTA raqamga qo'ng'iroq
                  // qilardi. Endi qiymat bo'lmasa tugma umuman yo'q.
                  if (phone.isEmpty && telegram.isEmpty)
                    Text(
                      l10n.expertContactMissing,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        // Shisha ostida `textMuted*` 3.46:1 — AA'dan past.
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    )
                  else
                    Row(
                      children: [
                        if (phone.isNotEmpty)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _callPhone(context, phone),
                              style: OutlinedButton.styleFrom(
                                // 1-BAND: `emerald` matn yorug' fonda 2.42:1.
                                foregroundColor: AppTone.success.on(isDark),
                                side: BorderSide(
                                    color: AppTone.success.accent(isDark)),
                                minimumSize: const Size.fromHeight(46),
                              ),
                              icon: const Icon(Icons.phone_in_talk_rounded,
                                  size: AppIconSize.sm),
                              label: Text(
                                l10n.expertCall,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        if (phone.isNotEmpty && telegram.isNotEmpty)
                          const Gap(AppSpacing.md),
                        if (telegram.isNotEmpty)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openTelegram(context, telegram),
                              style: OutlinedButton.styleFrom(
                                // 2-BAND: `lexBlue` matn 3.91:1 / 4.30:1.
                                foregroundColor: AppTone.info.on(isDark),
                                side: BorderSide(
                                    color: AppTone.info.accent(isDark)),
                                minimumSize: const Size.fromHeight(46),
                              ),
                              icon: const Icon(Icons.send_rounded,
                                  size: AppIconSize.sm),
                              label: Text(
                                l10n.expertTelegram,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),

                      const Gap(AppSpacing.bottomSafe),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBox({
    required String title,
    required String value,
    required String subtitle,
    required bool isDark,
  }) {
    return Expanded(
      child: ModernContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        // FON SHAFFOF EMAS. Ilgari yorug' mavzuda `primary.withValues(alpha:
        // 0.05)` edi — modal foni endi o'zi ham shaffof bo'lgani uchun
        // shaffoflik SHAFFOFLIK USTIGA tushardi va blok ichidagi kontrast
        // ekran ostidagi kontentga bog'liq bo'lib qolardi. `alphaBlend`
        // AYNI rangni beradi (#ECEFF1), lekin qiymati QAT'IY: `primary`
        // matn 15.46:1.
        backgroundColor: isDark
            ? AppColors.cardDark
            : Color.alphaBlend(
                AppColors.primary.withValues(alpha: 0.05),
                AppColors.backgroundLight,
              ),
        borderColor: isDark ? AppColors.borderDark : AppColors.borderLight,
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                // 4-BAND: qorong'ida `indigo` `cardDark` ustida 3.27:1 edi
                // (15 px qalin matn "katta matn" EMAS) → 7.34:1.
                color: isDark
                    ? AppColors.indigoOnTintDark
                    : AppColors.primary,
              ),
            ),
            const Gap(2),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                // 10 px → 11 px (loyihadagi poli) va `textMuted*` →
                // `textSecondary*`: 10 px matn shisha ostida o'qilmasdi.
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

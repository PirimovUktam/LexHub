import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/expert_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/consultations/presentation/pages/book_consultation_page.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:url_launcher/url_launcher.dart';

/// Advokat profili (bottom sheet).
///
/// §6: bo'sh maydonlar TO'QIMA qiymat bilan to'ldirilmaydi — litsenziya,
/// manzil, bio va aloqa tugmalari faqat bazada REAL qiymat bo'lganda
/// ko'rsatiladi. "Maslahat turi" satri butunlay olib tashlandi: bu ustun
/// `public_expert_profiles_view` da yo'q, ya'ni u har doim hardcoded
/// `ConsultationType.all` ("Barcha turlar") — bazada tasdiqlanmagan da'vo.
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
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const Gap(12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Gap(12),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Profile Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: isDark ? AppColors.indigo : AppColors.primary,
                        child: Text(
                          // Bo'sh ism `substring(0, 1)` da RangeError berardi.
                          expertAvatarInitial(expert),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Gap(16),
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
                                if (expert.isVerified)
                                  Icon(
                                    Icons.verified_rounded,
                                    color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const Gap(4),
                            Text(
                              expertSpecializationText(l10n, expert),
                              style: TextStyle(
                                color: isDark ? AppColors.indigoLight : AppColors.primaryLight,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            // Litsenziya FAQAT bazada raqam bo'lsa (§6):
                            // ilgari bo'sh ustun `ADV-VERIFIED` deb ko'rsatilardi.
                            if (license.isNotEmpty) ...[
                              const Gap(4),
                              Text(
                                l10n.expertLicenseLine(license),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Gap(18),

                  // METRIK BLOKLAR — TO'QIMA RAQAM YO'Q (§6).
                  // Bahosi yo'q advokat "⭐ 5.0" emas, "—" + "Baho yo'q";
                  // tajriba/yutuq 0 bo'lsa ham raqam O'YLAB TOPILMAYDI.
                  Row(
                    children: [
                      _buildMetricBox(
                        title: l10n.expertMetricRating,
                        value: expert.reviewsCount > 0 ? "⭐ ${expert.rating}" : "—",
                        subtitle: expert.reviewsCount > 0
                            ? l10n.expertMetricReviews(expert.reviewsCount)
                            : l10n.expertNoRating,
                        isDark: isDark,
                      ),
                      const Gap(10),
                      _buildMetricBox(
                        title: l10n.expertMetricExperience,
                        value: expert.experienceYears > 0
                            ? l10n.expertMetricYears(expert.experienceYears)
                            : "—",
                        subtitle: l10n.expertMetricPractice,
                        isDark: isDark,
                      ),
                      const Gap(10),
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

                  const Gap(18),

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
                          const Gap(8),
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
                    const Gap(14),
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
                              const Icon(Icons.location_on_outlined,
                                  color: AppColors.crimson, size: 20),
                              const Gap(8),
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
                          const Gap(10),
                        ],
                        Row(
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              color: isDark ? AppColors.amber : AppColors.amberDark,
                              size: 20,
                            ),
                            const Gap(8),
                            Expanded(
                              child: Text(
                                expertPriceText(l10n, expert),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.amber : AppColors.amberDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Gap(20),

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
                        backgroundColor: isDark ? AppColors.indigo : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded, size: 20),
                      label: Text(
                        l10n.expertBookConsultation,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const Gap(12),

                  // ALOQA TUGMALARI — FAQAT REAL qiymat bo'lganda (§6).
                  // Ilgari bo'sh `phone` ustuni `+998901234567` bilan
                  // to'ldirilardi: foydalanuvchi SOXTA raqamga qo'ng'iroq
                  // qilardi. Endi qiymat bo'lmasa tugma umuman yo'q.
                  if (phone.isEmpty && telegram.isEmpty)
                    Text(
                      l10n.expertContactMissing,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight,
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
                                foregroundColor: AppColors.emerald,
                                side: const BorderSide(color: AppColors.emerald),
                                minimumSize: const Size.fromHeight(46),
                              ),
                              icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                              label: Text(
                                l10n.expertCall,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        if (phone.isNotEmpty && telegram.isNotEmpty) const Gap(12),
                        if (telegram.isNotEmpty)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openTelegram(context, telegram),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.lexBlue,
                                side: const BorderSide(color: AppColors.lexBlue),
                                minimumSize: const Size.fromHeight(46),
                              ),
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                l10n.expertTelegram,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),

                  const Gap(32),
                ],
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        backgroundColor: isDark
            ? AppColors.cardDark
            : AppColors.primary.withValues(alpha: 0.05),
        borderColor: isDark ? AppColors.borderDark : AppColors.borderLight,
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: isDark ? AppColors.indigo : AppColors.primary,
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
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

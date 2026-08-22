import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyRightsPage extends StatelessWidget {
  const EmergencyRightsPage({super.key});

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.emergencyCallFailed(phone))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    final emergencyProtocols = [
      {
        'title': "1. Hibsga olish va ushlab turishda",
        'subtitle': "Miranda qoidasi va konstitutsiyaviy kafolatlar",
        'icon': Icons.gavel_rounded,
        'color': isDark ? AppColors.crimson : AppColors.crimsonDark,
        'rules': [
          "Konstitutsiya 28-moddasi: Nima uchun ushlab turilganingiz va huquqlaringiz darhol tushuntirilishi shart.",
          "Sukut saqlash huquqi: 'Advokatim kelmaguncha ko'rsatuv bermayman' deyishga 100% qonuniy haqlisiz.",
          "Telefon qo'ng'irog'i: Yaqinlaringiz yoki advokatga 1 marta bepul qo'ng'iroq qilish huquqi berilishi shart.",
          "Ushlab turish muddati: Sud qarorisiz shaxsni 48 soatdan ortiq ushlab turish qat'iyan taqiqlanadi.",
        ],
      },
      {
        'title': "2. Shaxsiy va avtotransport tintuvida",
        'subtitle': "Tintuv va ko'zdan kechirish qoidalari",
        'icon': Icons.security_rounded,
        'color': isDark ? AppColors.amber : AppColors.amberDark,
        'rules': [
          "Tintuv faqat tergovchi qarori yoki sud ajrimi asosida, xolislar (kamida 2 nafar) yoki uzluksiz videoyozuv ishtirokida o'tkaziladi.",
          "Shaxsiy tintuv faqat tintuv qilinayotgan shaxs bilan bir xil jinsdagi shaxs tomonidan o'tkazilishi shart.",
          "Har bir olingan buyum va ashyo bayonnomaga darhol kiritilishi va sizga nusxasi berilishi lozim.",
        ],
      },
      {
        'title': "3. YPX (GAI) xodimi to'xtatganda",
        'subtitle': "Haydovchining qonuniy kafolatlari",
        'icon': Icons.directions_car_rounded,
        'color': isDark ? AppColors.lexBlueLight : AppColors.lexBlue,
        'rules': [
          "Xodim o'zini tanishtirishi, lavozimi va to'xtatish sababini ma'lum qilishi shart.",
          "Siz xodimning xizmat guvohnomasini ko'rish va ma'lumotlarini yozib olishga haqlisiz.",
          "Haydovchi avtomobildan tushmasdan muloqot qilishga va jarayonni audio/videoga olishga haqli.",
        ],
      },
      {
        'title': "4. Majburiy mehnatga jalb qilishda",
        'subtitle': "Hokimiyat va ish beruvchi noqonuniy talablari",
        'icon': Icons.work_off_rounded,
        'color': isDark ? AppColors.emergencyDark : AppColors.riskCritical,
        'rules': [
          "Konstitutsiya 44-moddasi: Majburiy mehnat qat'iyan taqiqlanadi.",
          "Xodimni mehnat shartnomasida ko'rsatilmagan ishlarga (hashar, obodonlashtirish, qishloq xo'jaligi) majburlash jinoiy javobgarlikka sabab bo'ladi.",
          "Bunday talab bo'yicha Davlat mehnat inspeksiyasiga yoki 1092 / 1002 raqamlariga xabar bering.",
        ],
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.emergencyRightsTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hotlines Quick Grid
            Text(
              l10n.emergencyHotlinesTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Gap(10),
            Row(
              children: [
                _buildHotlineButton(
                  context,
                  title: l10n.hotlineProsecutor,
                  phone: "1002",
                  color: isDark ? AppColors.indigo : AppColors.primary,
                ),
                const Gap(10),
                _buildHotlineButton(
                  context,
                  title: l10n.hotlineInterior,
                  phone: "102",
                  color: AppColors.crimson,
                ),
              ],
            ),
            const Gap(10),
            Row(
              children: [
                _buildHotlineButton(
                  context,
                  title: l10n.hotlineOmbudsman,
                  phone: "1096",
                  color: AppColors.lexBlue,
                ),
                const Gap(10),
                _buildHotlineButton(
                  context,
                  title: l10n.hotlineLaborInspection,
                  phone: "1092",
                  color: AppColors.emerald,
                ),
              ],
            ),

            const Gap(24),

            Text(
              l10n.emergencyProtocolsTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Gap(12),

            ...emergencyProtocols.map((protocol) {
              final color = protocol['color'] as Color;
              final rules = protocol['rules'] as List<String>;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ModernContainer(
                  borderColor: color.withValues(alpha: 0.25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              protocol['icon'] as IconData,
                              color: color,
                              size: 22,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  protocol['title'] as String,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  protocol['subtitle'] as String,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Gap(14),
                      ...rules.map(
                        (rule) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 16,
                                color: isDark ? AppColors.indigo : AppColors.primary,
                              ),
                              const Gap(8),
                              Expanded(
                                child: Text(
                                  rule,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHotlineButton(
    BuildContext context, {
    required String title,
    required String phone,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: ModernContainer(
        onTap: () => _call(context, phone),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: color.withValues(alpha: isDark ? 0.16 : 0.08),
        borderColor: color.withValues(alpha: 0.25),
        child: Row(
          children: [
            Icon(Icons.phone_rounded, color: color, size: 20),
            const Gap(8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    phone,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

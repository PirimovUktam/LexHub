import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';
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
        'tone': AppTone.danger,
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
        'tone': AppTone.warning,
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
        'tone': AppTone.info,
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
        'tone': AppTone.critical,
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
                  onTint:
                      isDark ? AppColors.indigoOnDark : AppColors.primary,
                ),
                const Gap(10),
                _buildHotlineButton(
                  context,
                  title: l10n.hotlineInterior,
                  phone: "102",
                  color: AppColors.crimson,
                  onTint: isDark
                      ? AppColors.emergencyDark
                      : AppColors.emergencyStrong,
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
                  onTint: isDark
                      ? AppColors.lexBlueOnDark
                      : AppColors.lexBlueStrong,
                ),
                const Gap(10),
                _buildHotlineButton(
                  context,
                  title: l10n.hotlineLaborInspection,
                  phone: "1092",
                  color: AppColors.emerald,
                  onTint: isDark
                      ? AppColors.emeraldOnDark
                      : AppColors.emeraldStrong,
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
              // O'LCHANGAN DEFEKT: har bir karta o'z XOM aksentini ham
              // fon tinti, ham IKONKA rangi qilib ishlatardi. Ikonka o'z
              // tintining ustida: `amberDark` yorug'da 2.80:1 — 1.4.11
              // (ikonka uchun 3:1) dan PAST; `lexBlue` 3.52, `crimson`
              // qorong'ida 3.21 — qolganlari ham chegarada turardi.
              // Endi karta BITTA semantik ton saqlaydi: fon/chegara aksentdan,
              // ikonka esa shu tonning kontrastli juftidan olinadi. Yon
              // ta'siri: 4-karta qorong'ida ham binafsha (kritik) bo'ladi —
              // ilgari u qizilga o'zgarib, rang kodlashni buzardi.
              final tone = protocol['tone'] as AppTone;
              final color = tone.accent(isDark);
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
                              color: tone.on(isDark),
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
                              // O'LCHANGAN: qorong'ida `indigo` `cardDark`
                              // ustida 3.27:1 — 1.4.11 chegarasida. Ton:
                              // 7.34:1 (yorug' `primary` 17.85:1 o'zgarmaydi).
                              Icon(
                                Icons.shield_outlined,
                                size: 16,
                                color: isDark
                                    ? AppTone.accentIndigo.on(true)
                                    : AppColors.primary,
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
    required Color onTint,
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
            // IKONKA ham `onTint` da: to'yingan aksent (`color`) tint ustida
            // 2.10:1 gacha tushardi — grafik obyekt uchun ham 3:1 talab
            // qilinadi. `color` faqat fon tinti va chegarada qoladi.
            Icon(Icons.phone_rounded, color: onTint, size: 20),
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
                      // AKSENT EMAS: 15 px BOLD matn WCAG bo'yicha "katta"
                      // hisoblanmaydi (chegara 18.66 px bold), ya'ni 4.5:1
                      // talab qilinadi. O'lchov: `1092` #10B981 tint ustida
                      // 2.10:1 berardi. Batafsil — `AppColors.emeraldStrong`
                      // izohi.
                      color: onTint,
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

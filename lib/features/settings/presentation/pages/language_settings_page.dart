import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';
import 'package:lexhub/core/localization/locale_switch.dart';
import 'package:lexhub/core/theme/tone.dart';

/// Til tanlash ekrani.
///
/// Tanlov [LocaleCubit] orqali saqlanadi va butun ilovaga darhol qo'llanadi.
/// Navigator stack tegilmaydi — foydalanuvchi shu ekranda qoladi, sessiyasi
/// va ma'lumotlari yo'qolmaydi.
///
/// Almashtirish amali `switchAppLocale` ichida (`locale_switch.dart`) —
/// bosh sahifadagi tezkor tanlagich AYNI funksiyani chaqiradi, ya'ni xato
/// yo'li va SnackBar timing'i ikki joyda BIR XIL.
class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => const LanguageSettingsPage(),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.languagePageTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, current) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  l10n.languagePageSubtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...AppLocales.supported.map((locale) {
                final selected = locale.languageCode == current.languageCode;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      // O'LCHANGAN DEFEKT (radio bilan AYNI sabab):
                      // TANLANGAN kartaning 1.6 px chegarasi XOM `primary`
                      // edi — qorong'ida `cardDark` ustida 1.22:1, ya'ni
                      // "tanlangan" ramka KO'RINMASDI (1.4.11 — holat uchun
                      // 3:1). Neytral ton: yorug'da 17.85:1 (piksel o'zgarmadi),
                      // qorong'ida 13.98:1.
                      color: selected
                          ? AppTone.neutral.on(isDark)
                          : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: ListTile(
                    // Semantik yorliq: skrinreader tanlangan holatni o'qiydi.
                    //
                    // QURILMADA O'LCHANGAN DEFEKT (`04_til_dark.png`, piksel:
                    // sarlavha #6366F1, yuza #1E293B): `selected: true`
                    // sarlavha va tavsifni `colorScheme.primary` bilan
                    // bo'yaydi — qorong'ida bu XOM `indigo`, `cardDark`
                    // ustida 3.27:1 (sarlavha 16 px w700, tavsif 14 px —
                    // "yirik matn" EMAS, talab 4.5:1). Bu rang widget
                    // manbasida YO'Q edi, faqat qurilma pikselidan topildi.
                    // Tuzatish SAYTDA emas, MAVZUDA: `app_theme.dart`
                    // `listTileTheme.selectedColor` (qorong'i 7.34:1,
                    // yorug'da AYNI qiymat — piksel o'zgarmaydi).
                    selected: selected,
                    onTap: () => switchAppLocale(context, locale),
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      // O'LCHANGAN DEFEKT (og'ir): TANLANGAN radio XOM
                      // `primary` (#0F172A) edi — qorong'i mavzuda bu rang
                      // `surfaceDark` bilan AYNI, ya'ni ro'yxat foni bilan
                      // 1.00:1: "qaysi til tanlangan" belgisi QORONG'IDA
                      // MUTLAQO KO'RINMASDI (1.4.11 — holat uchun 3:1).
                      // Neytral ton: yorug' tomon PIKSELMA-PIKSEL o'zgarmaydi
                      // (`textPrimaryLight` == `primary`, 17.85:1),
                      // qorong'ida 17.06:1.
                      color: selected
                          ? AppTone.neutral.on(isDark)
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                    ),
                    // Til nomi HAR DOIM o'z tilida (tarjima qilinmaydi).
                    title: Text(
                      AppLocales.nativeName(locale),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(AppLocales.englishName(locale)),
                    trailing: selected
                        // O'LCHANGAN DEFEKT: tasdiq ikonkasi IKKI mavzuda ham
                        // XOM `emerald` edi — yorug' yuza ustida 2.54:1, ya'ni
                        // 1.4.11 (ikonka uchun 3:1) BUZILGAN. Ton: 7.68 / 9.29.
                        ? Icon(Icons.check_circle_rounded,
                            color: AppTone.success.on(isDark))
                        : null,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

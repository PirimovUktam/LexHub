import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';

/// Til tanlash ekrani.
///
/// Tanlov [LocaleCubit] orqali saqlanadi va butun ilovaga darhol qo'llanadi.
/// Navigator stack tegilmaydi — foydalanuvchi shu ekranda qoladi, sessiyasi
/// va ma'lumotlari yo'qolmaydi.
class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => const LanguageSettingsPage(),
      );

  Future<void> _select(BuildContext context, Locale locale) async {
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<LocaleCubit>();
    if (locale.languageCode == cubit.state.languageCode) return;
    try {
      await cubit.select(locale);
    } catch (_) {
      // Saqlash yiqilsa til O'ZGARMAYDI (LocaleCubit avval yozadi, keyin
      // emit qiladi) — shuning uchun foydalanuvchiga REAL xato ko'rsatiladi,
      // yolg'on "muvaffaqiyatli" xabari EMAS.
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.languageSaveFailed),
          backgroundColor: AppColors.crimson,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        // Yangi tildagi tasdiq (`context.l10n` allaqachon yangilangan).
        content: Text(
          context.l10n.languageChangedTo(AppLocales.nativeName(locale)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
                      color: selected
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: ListTile(
                    // Semantik yorliq: skrinreader tanlangan holatni o'qiydi.
                    selected: selected,
                    onTap: () => _select(context, locale),
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected
                          ? AppColors.primary
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
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.emerald)
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

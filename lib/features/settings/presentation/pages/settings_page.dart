import 'package:lexhub/core/theme/app_page_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';
import 'package:lexhub/features/settings/presentation/pages/language_settings_page.dart';

/// Sozlamalar ekrani.
///
/// Hozircha bitta bo'lim — til. Ataylab alohida ekran: keyingi sozlamalar
/// (mavzu, bildirishnomalar) shu yerga qo'shiladi, Profil sahifasi esa
/// sozlamalar ro'yxatiga aylanib ketmaydi.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SettingsPage());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: AppPageBody(
          child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            // AYNI DEFEKT `profile_tab_page.dart` da ham bor edi (o'lchangan,
            // Pixel 9 logcat 2026-08-26): oq fonli `Container` ichidagi
            // `ListTile` "ink splashes may be invisible" assertion'ini beradi
            // va til qatorini bosganda ripple ko'rinmaydi. `Material` ink
            // uchun sirt beradi, fon rangini o'zgartirmaydi.
            child: Material(
              type: MaterialType.transparency,
              child: BlocBuilder<LocaleCubit, Locale>(
                builder: (context, locale) {
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTone.accentIndigo.bg(isDark),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.translate_rounded,
                          color: AppTone.accentIndigo.on(isDark), size: 24),
                    ),
                    title: Text(
                      l10n.settingsLanguageTile,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.settingsLanguageSubtitle),
                        const SizedBox(height: 8),
                        Text(AppLocales.nativeName(locale),
                            style: Theme.of(context).textTheme.labelLarge),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context)
                        .push(LanguageSettingsPage.route()),
                  );
                },
              ),
            ),
          ),
        ],
      )),
    );
  }
}

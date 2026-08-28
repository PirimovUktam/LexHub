/// BOSH SAHIFA HERO KARTASI — ekranning birinchi ekran maydoni.
///
/// NIMA UCHUN: ilgari bosh sahifa "salom + platforma nomi + qidiruv paneli"
/// bilan boshlanardi. Yangi foydalanuvchi birinchi 3 sekundda NIMA QILA
/// OLISHINI tushunmasdi — ilova nomi hech qanday harakatni bildirmaydi.
/// Endi eng ko'p ishlatiladigan harakat (QONUN/SAVOL QIDIRISH) eng katta va
/// eng kontrastli element bo'ldi.
///
/// ROL CHIPI FAQAT O'QISH UCHUN: dizayn namunasida rol "dropdown" ko'rinishida
/// edi. LexHub'da rol `profiles.role` ustunidan keladi va RLS/RBAC uchun
/// yagona haqiqat manbasi — foydalanuvchi uni UI'dan TANLAY OLMAYDI.
/// Shuning uchun bu yerda `DropdownButton` emas, oddiy `Container` bor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/role_labels.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_state.dart';

class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({super.key, required this.onSearchTap});

  /// Qidiruv panelini bosganda `SearchPage` ochiladi. Bu yerda hech qanday
  /// so'rov yuborilmaydi — panel faqat NAVIGATSIYA (shuning uchun matn ham
  /// "AI tahlil" emas, "Qidirish").
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primaryLight],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Dekorativ ikonka — `Positioned` ATAYLAB `Stack` chetidan
          // chiqib ketmaydi (`ClipRRect` yo'q), aks holda katta shrift
          // masshtabida matn ustiga tushardi.
          Positioned(
            right: -8,
            top: -6,
            child: Icon(
              Icons.gavel_rounded,
              size: 88,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GreetingRow(),
              const Gap(AppSpacing.md),
              Text(
                l10n.homeHeroTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const Gap(AppSpacing.xxs),
              Text(
                l10n.homeHeroSubtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Gap(AppSpacing.lg),
              _HeroSearchField(onTap: onSearchTap),
            ],
          ),
        ],
      ),
    );
  }
}

/// Salomlashish + ism + FAQAT O'QISH uchun rol chipi.
///
/// `AuthBloc` `main.dart` da butun ilova bo'ylab berilgan, shuning uchun
/// bu yerda yangi provider yoki so'rov KERAK EMAS — qo'shimcha network
/// chaqiruvi qo'shilmaydi.
class _GreetingRow extends StatelessWidget {
  const _GreetingRow();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final profile = state is Authenticated ? state.profile : null;
        final name = profile?.fullName.trim();

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeGreeting,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Ism BO'SH bo'lsa qator umuman chizilmaydi — "Foydalanuvchi"
                  // kabi to'ldiruvchi matn ko'rsatish yolg'on shaxsiylashtirish
                  // taassurotini beradi.
                  if (name != null && name.isNotEmpty)
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            if (profile != null) _RoleChip(role: profile.role.toDbValue()),
          ],
        );
      },
    );
  }
}

/// Rol yorlig'i — XOM DB qiymati ko'rsatilmaydi, `role_labels.dart` orqali
/// tarjima qilinadi va noma'lum rol uchun eng past imtiyozli yorliqqa
/// tushadi (fail-closed).
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: AppIconSize.xs,
            color: Colors.white.withValues(alpha: 0.75),
          ),
          const Gap(AppSpacing.xxs),
          Text(
            roleLabelFromDbValue(context.l10n, role),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Oq "pill" qidiruv paneli — bu HAQIQIY `TextField` EMAS, tugma.
///
/// NIMA UCHUN: haqiqiy input qo'yilsa klaviatura hero kartasi ustida
/// ochilib, karta va uning ostidagi bo'limlar siljib ketardi; qidiruv
/// mantig'i esa allaqachon `SearchPage` ichida (debounce, natija holatlari,
/// bo'sh holat). Ikkinchi nusxa yaratish §9 ga zid.
class _HeroSearchField extends StatelessWidget {
  const _HeroSearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Semantics(
      button: true,
      // `label:` YO'Q: ichidagi ko'rsatma matni va "Qidirish" yorlig'i
      // semantikasi shu qobiqqa qo'shiladi — tashqi yorliq berilsa
      // ko'rsatma ikki marta o'qilardi.
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: AppIconSize.md,
                  color: AppColors.textSecondaryLight,
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.homeQueryHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // `textMutedLight` EMAS: bu "placeholder" emas, TUGMA
                    // yorlig'i. O'lchov tarixi: bu izoh yozilganda
                    // `textMutedLight` #94A3B8 edi va oq fon ustida 2.56:1
                    // berardi (WCAG AA 4.5:1 dan past). Token keyinchalik
                    // #64748B ga tuzatildi (4.76:1), ya'ni endi AA'dan
                    // O'TADI — lekin bu yer baribir `textSecondaryLight`
                    // (7.58:1) da qoladi: bosiladigan element yorlig'i
                    // ikkilamchi izohdan ko'zga ko'proq tashlanishi kerak.
                    // Qulf: `test/core/theme/color_contrast_test.dart`.
                    style: const TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    l10n.homeAiAnalyzeButton,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

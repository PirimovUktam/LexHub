import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/role_labels.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_event.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_state.dart';
import 'package:lexhub/features/auth/presentation/pages/login_page.dart';
import 'package:lexhub/features/auth/presentation/widgets/auth_gradient_button.dart';
import 'package:lexhub/features/legal_experts/presentation/pages/expert_moderation_page.dart';
import 'package:lexhub/features/settings/presentation/pages/settings_page.dart';

class ProfileTabPage extends StatelessWidget {
  const ProfileTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    // "Tizimdan chiqish" — ikki mavzuda AA beruvchi xavf rangi (o'lchov
    // tugma yonidagi izohda).
    final signOutColor =
        isDark ? AppColors.emergencyDark : AppColors.emergencyStrong;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          final profile = state.profile;
          final email = state.user.email;
          final fullName = profile?.fullName ?? l10n.authDefaultUserName;
          final role = profile?.role ?? UserRole.citizen;
          final reputation = profile?.reputationPoints ?? 10;
          final isVerified = profile?.isVerified ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Avatar Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: isDark ? AppColors.cardDark : const Color(0xFFE2E8F0),
                            child: Text(
                              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                // O'LCHANGAN DEFEKT (qurilma, `42_profile_dark.png`,
                                // piksel: harf #0F172A, halqa #1E293B): qorong'i
                                // mavzuda harf `cardDark` ustida 1.22:1 berardi —
                                // bosh harf KO'RINMASDI. `primary` yorug' mavzuda
                                // to'g'ri (#E2E8F0 ustida 14.48:1), shuning uchun
                                // faqat qorong'i shox almashtirildi: 13.98:1.
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          if (isVerified)
                            Container(
                              padding: const EdgeInsets.all(4),
                              // O'LCHANGAN DEFEKT: ustidagi OQ 14 px "check"
                              // glifi `emerald` to'ldirmasi ustida 2.54:1 edi
                              // — glif MA'NO tashuvchi grafik, ya'ni 1.4.11
                              // bo'yicha 3:1 kerak. `emeraldDark`: 3.77:1
                              // (fon rangi ikki mavzuda ham bir xil, chunki
                              // nishon O'ZI fonni beradi). Yashil o'qilishi
                              // saqlanadi — `emeraldStrong` (7.68) bu
                              // o'lchamdagi nishon uchun deyarli qora ko'kish
                              // yashil bo'lib qolardi.
                              decoration: const BoxDecoration(
                                color: AppColors.emeraldDark,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        fullName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Role & Reputation Badges
                      //
                      // O'LCHANGAN DEFEKT: ikki badge ham "aksent@alfa fon +
                      // AKSENTNING O'ZI matn" naqshini ishlatardi, ya'ni matn
                      // mavzuni bilmasdi:
                      //   rol badge'i  — `indigo` tint ustida: yorug' 3.85:1,
                      //                  qorong'i 2.89:1 (qurilmada xira
                      //                  ko'rinardi: `42_profile_dark.png`);
                      //   reputatsiya  — `amberDark` tint ustida: yorug'
                      //                  2.84:1, qorong'i 4.37:1.
                      // Ikkisi ham 12 px w700 — bu "large text" EMAS, talab
                      // 4.5:1. `AppTone` retsepti: fon/chegara aksentdan,
                      // matn/ikonka esa mavzuga mos to'yingan juftdan.
                      // Keyin: rol 5.42/6.49, reputatsiya 6.31/9.66.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTone.accentIndigo.bg(isDark, alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppTone.accentIndigo.border(isDark)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_outlined,
                                    size: 14,
                                    color: AppTone.accentIndigo.on(isDark)),
                                const SizedBox(width: 5),
                                Text(
                                  roleLabelFromDbValue(l10n, role.toDbValue()),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTone.accentIndigo.on(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTone.warning.bg(isDark, alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: AppTone.warning.border(isDark)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded,
                                    size: 15, color: AppTone.warning.on(isDark)),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.profileReputationPoints(reputation),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTone.warning.on(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Account Information & Security Tile
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  // O'LCHANGAN DEFEKT (Pixel 9 logcat, 2026-08-26): bu
                  // `Container` fon rangi bergani uchun ichidagi `ListTile`lar
                  // "ListTile background color or ink splashes may be
                  // invisible" assertion'ini chiqargan — Sozlamalar qatorini
                  // bosganda ripple KO'RINMAGAN. Yechim framework tavsiya
                  // qilgani: `ListTile`larga o'z `Material` ajdodini berish.
                  // `MaterialType.transparency` fon rangini o'zgartirmaydi,
                  // faqat ink uchun sirt yaratadi.
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              // O'LCHANGAN DEFEKT (qurilma, `42_profile_dark.png`):
                              // plitka foni `primary@0.1`, ikonka esa `primary`
                              // (#0F172A) edi. Qorong'i mavzuda karta yuzasi
                              // `surfaceDark` ham #0F172A — piksel o'lchovi
                              // plitka va karta fonini AYNAN bir xil qaytardi
                              // (#0F172A == #0F172A, 1.00:1): "Xavfsizlik & RLS"
                              // ikonkasi ekranda BUTUNLAY yo'q edi.
                              // `AppTone.neutral` — rang kodlashsiz plitka:
                              // yorug' 14.56:1, qorong'i 13.15:1.
                              color: AppTone.neutral.bg(isDark, alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.security_rounded,
                                color: AppTone.neutral.on(isDark), size: 20),
                          ),
                          title: Text(l10n.profileSecurityTitle,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(l10n.profileSecuritySubtitle,
                              style: const TextStyle(fontSize: 12)),
                          // Yorug' mavzuda `emerald` oq yuza ustida 2.54:1 —
                          // grafik uchun ham (1.4.11 -> 3:1) YETMAYDI.
                          // `AppTone.success.on` mavzuga mos to'yingan juft.
                          trailing: Icon(Icons.check_circle_rounded,
                              color: AppTone.success.on(isDark), size: 20),
                        ),
                        Divider(
                          height: 1,
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                        // Sozlamalar -> Til (§11). Profil bo'limidan ochiladi.
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTone.accentIndigo.bg(isDark, alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            // Qorong'ida `indigo` o'z tinti ustida 3.89:1 —
                            // grafik uchun o'tadi, lekin qo'shni plitkalar bilan
                            // bir xil retseptga keltirildi: 5.56/7.52.
                            child: Icon(Icons.settings_outlined,
                                color: AppTone.accentIndigo.on(isDark), size: 20),
                          ),
                          title: Text(l10n.settingsTitle,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(l10n.settingsLanguageSubtitle,
                              style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              size: 20),
                          onTap: () =>
                              Navigator.of(context).push(SettingsPage.route()),
                        ),
                        // ARIZA MODERATSIYASI — FAQAT admin/moderator.
                        //
                        // Bu tekshiruv UX uchun: oddiy fuqaroga foydasiz
                        // ekranni ko'rsatmaslik. ISHONCH CHEGARASI EMAS —
                        // `expert_profiles` SELECT RLS admin bo'lmagan
                        // chaqiruvchiga faqat O'Z arizasini beradi va
                        // `verify_expert_application()` `is_admin_or_moderator()`
                        // bo'lmasa `Access Denied` qaytaradi. APK'ni
                        // o'zgartirib bu plitkani zo'rlab ochish hech narsa
                        // bermaydi.
                        if (role == UserRole.admin ||
                            role == UserRole.moderator) ...[
                          Divider(
                            height: 1,
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTone.warning.bg(isDark, alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.verified_user_outlined,
                                  color: AppTone.warning.on(isDark), size: 20),
                            ),
                            title: Text(l10n.moderationTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(l10n.moderationEntrySubtitle,
                                style: const TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                size: 20),
                            onTap: () => Navigator.of(context)
                                .push(ExpertModerationPage.route()),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Sign Out Button
                //
                // O'LCHANGAN: `crimson` (#EF4444) yorug' mavzu foni
                // (`backgroundLight`) ustida 3.60:1 — 14 px w700 matn uchun AA
                // (4.5:1) dan PAST. Qorong'ida esa `crimson` 4.68:1 bilan
                // o'tardi, shuning uchun ikki mavzuga alohida to'yingan juft
                // berildi: yorug' `emergencyStrong` 6.18:1, qorong'i
                // `emergencyDark` 6.36:1. Chegara ham shu rangda — kontur
                // grafik sifatida 3:1 dan yuqori.
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<AuthBloc>().add(const SignOutEvent());
                  },
                  icon: Icon(Icons.logout_rounded, color: signOutColor, size: 18),
                  label: Text(
                    l10n.authSignOut,
                    style: TextStyle(
                      color: signOutColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: signOutColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          );
        }

        // Unauthenticated State
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : const Color(0xFFEEF2F6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 32,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.authSignedOutTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.authSignedOutSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 24),
                AuthGradientButton(
                  text: l10n.authLoginOrRegister,
                  icon: Icons.login_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).push(SettingsPage.route()),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: Text(l10n.settingsTitle),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

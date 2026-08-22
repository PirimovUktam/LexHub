import pathlib, sys

Q = "\\'"
p = pathlib.Path('lib/features/auth/presentation/pages/profile_tab_page.dart')
s = p.read_text(encoding='utf-8')

s = s.replace("import 'package:lexhub/core/constants/app_colors.dart';",
              "import 'package:lexhub/core/constants/app_colors.dart';\n"
              "import 'package:lexhub/core/localization/l10n.dart';\n"
              "import 'package:lexhub/core/localization/role_labels.dart';", 1)
s = s.replace("import 'package:lexhub/features/auth/presentation/widgets/auth_gradient_button.dart';",
              "import 'package:lexhub/features/auth/presentation/widgets/auth_gradient_button.dart';\n"
              "import 'package:lexhub/features/settings/presentation/pages/settings_page.dart';", 1)

pairs = [
  ("    final isDark = Theme.of(context).brightness == Brightness.dark;\n",
   "    final isDark = Theme.of(context).brightness == Brightness.dark;\n"
   "    final l10n = context.l10n;\n"),

  ("final fullName = profile?.fullName ?? 'Foydalanuvchi';",
   "final fullName = profile?.fullName ?? l10n.authDefaultUserName;"),

  # Rol yorlig'i: DB qiymati o'zgarmaydi, faqat ko'rinadigan matn tarjima qilinadi.
  ("""                                Text(
                                  role.displayName,
                                  style: const TextStyle(""",
   """                                Text(
                                  roleLabelFromDbValue(l10n, role.toDbValue()),
                                  style: const TextStyle("""),

  ("""                                Text(
                                  '$reputation ball',
                                  style: const TextStyle(""",
   """                                Text(
                                  l10n.profileReputationPoints(reputation),
                                  style: const TextStyle("""),

  ("""                        title: const Text('Xavfsizlik & RLS Himoyasi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('PostgreSQL Row Level Security faol', style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),""",
   """                        title: Text(l10n.profileSecurityTitle,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(l10n.profileSecuritySubtitle,
                            style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 20),
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
                            color: AppColors.indigo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.settings_outlined,
                              color: AppColors.indigo, size: 20),
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
                    ],
                  ),
                ),
                const SizedBox(height: 28),"""),

  ("""                  label: const Text(
                    'Tizimdan chiqish',
                    style: TextStyle(""",
   """                  label: Text(
                    l10n.authSignOut,
                    style: const TextStyle("""),

  ("""                Text(
                  'Hisobingizga kiring',""",
   """                Text(
                  l10n.authSignedOutTitle,"""),

  ("""                Text(
                  'Savol berish, javoblarni baholash va advokatlar bilan maslahatlashish uchun tizimga kiring',""",
   """                Text(
                  l10n.authSignedOutSubtitle,"""),

  ("text: 'Tizimga kirish / Ro" + Q + "yxatdan o" + Q + "tish',",
   "text: l10n.authLoginOrRegister,"),

  # Mehmon (unauthenticated) holatida ham til almashish MUMKIN bo'lishi kerak.
  ("""                AuthGradientButton(
                  text: l10n.authLoginOrRegister,
                  icon: Icons.login_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                ),""",
   """                AuthGradientButton(
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
                ),"""),
]

for a, b in pairs:
    if a not in s:
        print("MISS:", repr(a[:100])); sys.exit(1)
    s = s.replace(a, b, 1)

p.write_text(s, encoding='utf-8')
print("profile OK")

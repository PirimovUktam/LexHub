import pathlib, sys

p = pathlib.Path('lib/features/auth/presentation/pages/register_page.dart')
s = p.read_text(encoding='utf-8')

s = s.replace("import 'package:lexhub/core/constants/app_colors.dart';",
              "import 'package:lexhub/core/constants/app_colors.dart';\nimport 'package:lexhub/core/localization/l10n.dart';")
s = s.replace("  Widget build(BuildContext context) {\n    final isDark = Theme.of(context).brightness == Brightness.dark;",
              "  Widget build(BuildContext context) {\n    final isDark = Theme.of(context).brightness == Brightness.dark;\n    final l10n = context.l10n;")

Q = "\\'"   # Dart escaped apostrophe as it appears in source

pairs = [
  ("'Ro" + Q + "yxatdan o" + Q + "tish',\n                      style: TextStyle(",
   "l10n.authRegisterTitle,\n                      style: TextStyle("),
  ("'LexHub orqali yuridik xizmatlar va jamoat forumidan to" + Q + "liq foydalaning',",
   "l10n.authRegisterSubtitle,"),
  ("label: 'To" + Q + "liq ism-sharifingiz',\n                            hintText: 'Bobur Mirzayev',",
   "label: l10n.authFieldFullName,\n                            hintText: l10n.authHintFullName,"),
  ("return 'Ism-sharifingizni kiriting';", "return l10n.validationNameRequired;"),
  ("return 'Ism juda qisqa';", "return l10n.validationNameTooShort;"),
  ("label: 'Email pochta',\n                            hintText: 'misol@domain.uz',",
   "label: l10n.authFieldEmail,\n                            hintText: l10n.authHintEmail,"),
  ("return 'Email manzilini kiriting';", "return l10n.validationEmailRequired;"),
  ("return 'To" + Q + "g" + Q + "ri email formatini kiriting';", "return l10n.validationEmailInvalid;"),
  ("label: 'Parol yaratish',\n                            hintText: 'Kamida 6 ta belgi',",
   "label: l10n.authFieldCreatePassword,\n                            hintText: l10n.authHintMinSixChars,"),
  ("return 'Parolni kiriting';", "return l10n.validationPasswordRequired;"),
  ("return 'Parol kamida 6 belgidan iborat bo" + Q + "lishi kerak';",
   "return l10n.validationPasswordTooShort;"),
  ("label: 'Parolni tasdiqlang',\n                            hintText: 'Parolni qayta kiriting',",
   "label: l10n.authFieldConfirmPassword,\n                            hintText: l10n.authHintConfirmPassword,"),
  ("return 'Parolni tasdiqlang';", "return l10n.validationConfirmPasswordRequired;"),
  ("return 'Kiritilgan parollar bir-biriga mos kelmadi';",
   "return l10n.validationPasswordsMismatch;"),
  ("text: 'Ro" + Q + "yxatdan o" + Q + "tish',\n                            icon: Icons.person_add_alt_1_rounded,",
   "text: l10n.authRegisterTitle,\n                            icon: Icons.person_add_alt_1_rounded,"),
  ("'Hisobingiz bormi? ',", "l10n.authHaveAccount,"),
  ("child: const Text(\n                            'Kirish',\n                            style: TextStyle(",
   "child: Text(\n                            l10n.authGoToLogin,\n                            style: const TextStyle("),
]

for a, b in pairs:
    if a not in s:
        print("MISS:", repr(a[:80]))
        sys.exit(1)
    s = s.replace(a, b, 1)

p.write_text(s, encoding='utf-8')
print("register OK")

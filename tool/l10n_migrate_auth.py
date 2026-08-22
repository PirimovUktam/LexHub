import pathlib, sys

Q = "\\'"

def patch(path, pairs, add_import=True, add_l10n=None):
    p = pathlib.Path(path)
    s = p.read_text(encoding='utf-8')
    if add_import and "core/localization/l10n.dart" not in s:
        s = s.replace("import 'package:lexhub/core/constants/app_colors.dart';",
                      "import 'package:lexhub/core/constants/app_colors.dart';\n"
                      "import 'package:lexhub/core/localization/l10n.dart';", 1)
    if add_l10n:
        if add_l10n not in s:
            print("MISS ANCHOR:", path, repr(add_l10n[:80])); sys.exit(1)
        s = s.replace(add_l10n, add_l10n + "\n    final l10n = context.l10n;", 1)
    for a, b in pairs:
        if a not in s:
            print("MISS:", path, repr(a[:90])); sys.exit(1)
        s = s.replace(a, b, 1)
    p.write_text(s, encoding='utf-8')
    print("OK", path)


patch('lib/features/auth/presentation/pages/login_page.dart',
      add_l10n="    final isDark = Theme.of(context).brightness == Brightness.dark;",
      pairs=[
        ("'O" + Q + "zbekiston Huquqiy Platformasi',", "l10n.appLegalPlatform,"),
        ("'Tizimga kirish',\n                              style: TextStyle(",
         "l10n.authLoginTitle,\n                              style: TextStyle("),
        ("label: 'Email pochta',\n                              hintText: 'misol@domain.uz',",
         "label: l10n.authFieldEmail,\n                              hintText: l10n.authHintEmail,"),
        ("return 'Email manzilini kiriting';", "return l10n.validationEmailRequired;"),
        ("return 'To" + Q + "g" + Q + "ri email formatini kiriting';",
         "return l10n.validationEmailInvalid;"),
        ("label: 'Maxfiy parol',\n                              hintText: 'Parolni kiriting',",
         "label: l10n.authFieldPassword,\n                              hintText: l10n.authHintPassword,"),
        ("return 'Parolni kiriting';", "return l10n.validationPasswordRequired;"),
        ("return 'Parol kamida 6 belgidan iborat bo" + Q + "lishi kerak';",
         "return l10n.validationPasswordTooShort;"),
        ("text: 'Tizimga kirish',\n                              icon: Icons.login_rounded,",
         "text: l10n.authLoginTitle,\n                              icon: Icons.login_rounded,"),
        ("'Hisobingiz yo" + Q + "qmi? ',", "l10n.authNoAccount,"),
        ("child: const Text(\n                              'Ro" + Q + "yxatdan o" + Q + "ting',\n                              style: TextStyle(",
         "child: Text(\n                              l10n.authGoToRegister,\n                              style: const TextStyle("),
        ("'Mehmon sifatida davom etish',", "l10n.authContinueAsGuest,"),
      ])

patch('lib/features/auth/presentation/pages/auth_gate_page.dart',
      add_l10n=None,
      pairs=[
        ("""                  const Text(
                    'O\\'zbekiston Huquqiy Platformasi',
                    style: TextStyle(""",
         """                  Text(
                    context.l10n.appLegalPlatform,
                    style: const TextStyle("""),
      ])

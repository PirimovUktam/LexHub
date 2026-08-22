import pathlib, sys

Q = "\\'"


def patch(path, pairs, imports=(), add_l10n=None):
    p = pathlib.Path(path)
    s = p.read_text(encoding='utf-8')
    for anchor, extra in imports:
        if extra.split("'")[1] in s:
            continue
        if anchor not in s:
            print("MISS IMPORT ANCHOR:", path, anchor); sys.exit(1)
        s = s.replace(anchor, anchor + "\n" + extra, 1)
    if add_l10n:
        if add_l10n not in s:
            print("MISS L10N ANCHOR:", path, repr(add_l10n[:80])); sys.exit(1)
        s = s.replace(add_l10n, add_l10n + "\n    final l10n = context.l10n;", 1)
    for a, b in pairs:
        if a not in s:
            print("MISS:", path, repr(a[:110])); sys.exit(1)
        s = s.replace(a, b, 1)
    p.write_text(s, encoding='utf-8')
    print("OK", path)


COLORS = "import 'package:lexhub/core/constants/app_colors.dart';"
L10N = "import 'package:lexhub/core/localization/l10n.dart';"
CATLBL = "import 'package:lexhub/core/localization/category_labels.dart';"

# ------------------------------------------------------------- ask dialog
patch('lib/features/community_forum/presentation/widgets/ask_community_dialog.dart',
      imports=[(COLORS, CATLBL + "\n" + L10N)],
      add_l10n="    final isDark = theme.brightness == Brightness.dark;",
      pairs=[
        # Auth-required dialog: `actionText` endi TARJIMA QILINGAN matn.
        ("""  static void showAuthRequiredDialog(BuildContext context, {required String actionText}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Tizimga kirish talab etiladi",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          "$actionText uchun avval tizimga kiring yoki yangi hisob oching.",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Bekor qilish"),
          ),""",
         """  static void showAuthRequiredDialog(BuildContext context, {required String actionText}) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.authRequiredTitle,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.authRequiredMessage(actionText),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionCancel),
          ),"""),
        ("""            child: const Text("Kirish / Ro'yxatdan o'tish"),""",
         """            child: Text(l10n.authLoginOrRegister),"""),
        # `show()` static: BuildContext bor, l10n undan olinadi.
        ("""    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      showAuthRequiredDialog(context, actionText: "Savol berish");
      return;
    }

    showModalBottomSheet(""",
         """    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      showAuthRequiredDialog(context,
          actionText: context.l10n.authActionAskQuestion);
      return;
    }

    showModalBottomSheet("""),
        ("""      AskCommunityDialog.showAuthRequiredDialog(context, actionText: "Savol berish");""",
         """      AskCommunityDialog.showAuthRequiredDialog(context,
          actionText: context.l10n.authActionAskQuestion);"""),
        ("""        const SnackBar(content: Text("Iltimos, savol matnini kiriting")),""",
         """        SnackBar(content: Text(context.l10n.askDialogEmptyBody)),"""),
        # `aiSummary` / `authorName` — DB'ga BORADIGAN qiymatlar, tarjima
        # qilinmaydi (§16: database values o'sha-o'sha qoladi).
        ("""                      Text(
                        "Hamjamiyatga Savol Berish",""",
         """                      Text(
                        l10n.askDialogTitle,"""),
        ("""                      Text(
                        "Privacy Guard: Telefon, pasport va kartalar avtomat yashiriladi",""",
         """                      Text(
                        l10n.askDialogPrivacyGuard,"""),
        ("""              decoration: const InputDecoration(labelText: "Kategoriya"),""",
         """              decoration:
                  InputDecoration(labelText: l10n.askDialogCategoryField),"""),
        # Dropdown: `value` DB nomi, ko'rinish tarjima qilinadi.
        ("""                return DropdownMenuItem<String>(
                  value: cat,
                  child: Text(cat),
                );""",
         """                return DropdownMenuItem<String>(
                  value: cat,
                  child: Text(categoryLabel(l10n, cat)),
                );"""),
        ("""              decoration: const InputDecoration(
                labelText: "Savol sarlavhasi (qisqacha)",
                hintText: "Masalan: Dam olish kunida majburiy ishlash...",
              ),""",
         """              decoration: InputDecoration(
                labelText: l10n.askDialogTitleField,
                hintText: l10n.askDialogTitleHint,
              ),"""),
        ("""              decoration: const InputDecoration(
                labelText: "Batafsil ma'lumot",
                hintText: "Yuridik muammoingizni erkin bayon qiling...",
              ),""",
         """              decoration: InputDecoration(
                labelText: l10n.askDialogBodyField,
                hintText: l10n.askDialogBodyHint,
              ),"""),
        ("""              title: const Text("Anonim tarzda e'lon qilish", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text("Ismingiz o'rniga 'Anonim fuqaro' ko'rsatiladi", style: TextStyle(fontSize: 11)),""",
         """              title: Text(l10n.askDialogAnonymousToggle,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(l10n.askDialogAnonymousSubtitle,
                  style: const TextStyle(fontSize: 11)),"""),
        ("""                        Text(
                          "Maxfiy ma'lumotlar aniqlandi va yashirildi:",""",
         """                        Text(
                          l10n.askDialogPiiDetected,"""),
        ("""              label: Text(_isAnonymous ? "Anonim tarzda chop etish" : "Savolni chop etish"),""",
         """              label: Text(_isAnonymous
                  ? l10n.askDialogPublishAnonymously
                  : l10n.askDialogPublish),"""),
      ])

print("ask dialog OK")

import pathlib, sys

Q = "\\'"   # Dart source'da ko'rinadigan escape qilingan apostrof


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
ROLELBL = "import 'package:lexhub/core/localization/role_labels.dart';"
STRINGS = "import 'package:lexhub/core/constants/app_strings.dart';\n"

# ---------------------------------------------------------------- forum page
patch('lib/features/community_forum/presentation/pages/community_forum_page.dart',
      imports=[(COLORS, CATLBL + "\n" + L10N)],
      add_l10n="    final isDark = theme.brightness == Brightness.dark;",
      pairs=[
        (STRINGS, ""),
        ("                AppStrings.communityQnA,", "                l10n.communityTitle,"),
        ("tooltip: AppStrings.askCommunity,", "tooltip: l10n.communityAskTooltip,"),
        # Filtr chip: `value` DB nomi bo'lib qoladi, faqat ko'rinish tarjima qilinadi.
        ("""                        label: Text(
                          cat,""",
         """                        label: Text(
                          categoryLabel(l10n, cat),"""),
        ("child: const Text(AppStrings.retry),", "child: Text(l10n.actionRetry),"),
        ("""                                Text(
                                  "Ushbu kategoriyada savollar topilmadi",
                                  style: theme.textTheme.bodyMedium,
                                ),""",
         """                                Text(
                                  l10n.communityEmptyInCategory,
                                  style: theme.textTheme.bodyMedium,
                                ),"""),
        ("""            label: const Text("Savol berish"),""",
         """            label: Text(l10n.communityAskCta),"""),
      ])

# ---------------------------------------------------------------- post card
patch('lib/features/community_forum/presentation/widgets/community_post_card.dart',
      imports=[(COLORS, CATLBL + "\n" + L10N)],
      add_l10n="    final isDark = theme.brightness == Brightness.dark;",
      pairs=[
        ("""                  child: Text(
                    post.category,""",
         """                  child: Text(
                    categoryLabel(l10n, post.category),"""),
        ("""                        Text(
                          "Maxfiy (Anonim)",""",
         """                        Text(
                          l10n.communityAnonymousBadge,"""),
        ("""                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 11, color: AppColors.emerald),
                        Gap(3),
                        Text(
                          "Advokat javobi bor",
                          style: TextStyle(""",
         """                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, size: 11, color: AppColors.emerald),
                        const Gap(3),
                        Text(
                          l10n.communityExpertAnswerBadge,
                          style: const TextStyle("""),
        ("""                          const Text(
                            "AI Tahlil xulosasi:",
                            style: TextStyle(""",
         """                          Text(
                            l10n.communityAiSummaryLabel,
                            style: const TextStyle("""),
        ("""                  post.isAnonymous ? "Anonim fuqaro" : post.authorName,""",
         """                  post.isAnonymous
                      ? l10n.communityAnonymousAuthor
                      : post.authorName,"""),
        ("""                    Text(
                      "${post.answersCount} ta javob",""",
         """                    Text(
                      l10n.communityAnswersCount(post.answersCount),"""),
        ("""                    label: const Text("AI tahlil", style: TextStyle(fontSize: 11)),""",
         """                    label: Text(l10n.communityAiAnalysis,
                        style: const TextStyle(fontSize: 11)),"""),
      ])

print("community batch OK")

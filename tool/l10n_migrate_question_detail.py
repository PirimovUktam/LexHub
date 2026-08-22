import pathlib, sys

def patch(path, pairs, imports=(), ):
    p = pathlib.Path(path)
    s = p.read_text(encoding='utf-8')
    for anchor, extra in imports:
        if extra.split("'")[1] in s:
            continue
        if anchor not in s:
            print("MISS IMPORT ANCHOR:", path, anchor); sys.exit(1)
        s = s.replace(anchor, anchor + "\n" + extra, 1)
    for a, b in pairs:
        if a not in s:
            print("MISS:", path, repr(a[:110])); sys.exit(1)
        s = s.replace(a, b, 1)
    p.write_text(s, encoding='utf-8')
    print("OK", path)


COLORS = "import 'package:lexhub/core/constants/app_colors.dart';"
EXTRA = ("import 'package:lexhub/core/localization/category_labels.dart';\n"
         "import 'package:lexhub/core/localization/l10n.dart';\n"
         "import 'package:lexhub/core/localization/role_labels.dart';")

patch('lib/features/community_forum/presentation/pages/question_detail_page.dart',
      imports=[(COLORS, EXTRA)],
      pairs=[
        ("import 'package:lexhub/core/constants/app_strings.dart';\n", ""),

        # --- _submitAnswer -------------------------------------------------
        ("""      AskCommunityDialog.showAuthRequiredDialog(context, actionText: "Javob yozish");""",
         """      AskCommunityDialog.showAuthRequiredDialog(context,
          actionText: context.l10n.authActionWriteAnswer);"""),

        # `authorName` / `authorRole` — DB'ga/cache'ga boradigan KANONIK
        # qiymatlar. Tarjima qilinsa bir foydalanuvchi yozgan javob boshqa
        # tildagi foydalanuvchiga inglizcha ko'rinardi (§16).
        ("""        authorName: asExpert ? "Ekspert Yurist" : "Fuqaro",
        isExpert: asExpert,
        authorRole: asExpert ? "Litsenziyaga ega advokat" : "Jamoat a'zosi",""",
         """        // TARJIMA QILINMAYDI: bu qiymatlar wire/cache shakliga boradi,
        // UI yorlig'i emas. Ko'rsatishda `answerAuthorRoleLabel()` ishlaydi.
        authorName: asExpert ? "Ekspert Yurist" : "Fuqaro",
        isExpert: asExpert,
        authorRole: asExpert ? "Litsenziyaga ega advokat" : "Jamoat a'zosi","""),

        ("""            content: Text(demoted
                ? "Javob saqlandi, lekin ODDIY javob sifatida: "
                    "ekspert javobi uchun profilingiz tasdiqlanmagan."
                : "Javobingiz muvaffaqiyatli saqlandi va e'lon qilindi!"),""",
         """            content: Text(demoted
                ? context.l10n.answerSubmitDemoted
                : context.l10n.answerSubmitSuccess),"""),

        # --- _voteAnswer / _acceptAnswer -----------------------------------
        ("""      AskCommunityDialog.showAuthRequiredDialog(context, actionText: "Ovoz berish");""",
         """      AskCommunityDialog.showAuthRequiredDialog(context,
          actionText: context.l10n.authActionVote);"""),
        ("""      AskCommunityDialog.showAuthRequiredDialog(context, actionText: "Javobni qabul qilish");""",
         """      AskCommunityDialog.showAuthRequiredDialog(context,
          actionText: context.l10n.authActionAcceptAnswer);"""),
        ("""        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Javob foydali (hal qilingan) deb belgilandi!"),
            backgroundColor: AppColors.emerald,
          ),
        );""",
         """        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.answerAcceptSuccess),
            backgroundColor: AppColors.emerald,
          ),
        );"""),

        # --- build ---------------------------------------------------------
        ("""    final isDark = theme.brightness == Brightness.dark;
    final post = widget.post;""",
         """    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final post = widget.post;"""),
        ("""        title: Text(
          "Savol tafsilotlari",""",
         """        title: Text(
          l10n.questionDetailTitle,"""),
        ("""                        child: Text(
                          post.category,""",
         """                        child: Text(
                          categoryLabel(l10n, post.category),"""),
        ("""                              Text("Anonim", style: TextStyle(""",
         """                              Text(l10n.communityAnonymousShort,
                                  style: TextStyle("""),
        ("""                            Text(
                              "LexHub AI Tezkor Xulosasi",""",
         """                            Text(
                              l10n.questionDetailAiSummary,"""),
        ("""                      Text(
                        "Javoblar va Maslahatlar (${_answers.length})",""",
         """                      Text(
                        l10n.questionDetailAnswersSection(_answers.length),"""),
        ("""                            Text(
                              "Hali hech kim javob yozmadi.\\nBirinchi bo'lib o'z tajribangiz yoki yuridik fikringizni bildiring!",""",
         """                            Text(
                              l10n.questionDetailEmptyAnswers,"""),
        ("""                        return _buildAnswerCard(context, answer, isDark);""",
         """                        return _buildAnswerCard(
                            context, answer, isDark, l10n);"""),
        ("""                          label: const Text("Advokat sifatida javob berish", style: TextStyle(fontSize: 11)),""",
         """                          label: Text(l10n.answerAsLawyerChip,
                              style: const TextStyle(fontSize: 11)),"""),
        ("""                        AppStrings.piiProtectedNotice,""",
         """                        l10n.communityPiiNotice,"""),
        ("""                            hintText: "Fikr yoki qonuniy maslahat yozing...",""",
         """                            hintText: l10n.answerInputHint,"""),

        # --- _buildAnswerCard ----------------------------------------------
        ("""  Widget _buildAnswerCard(BuildContext context, QuestionAnswer answer, bool isDark) {""",
         """  Widget _buildAnswerCard(
      BuildContext context, QuestionAnswer answer, bool isDark, AppL10n l10n) {"""),
        ("""                    Text(
                      answer.authorRole ?? 'Fuqaro',""",
         """                    Text(
                      answerAuthorRoleLabel(l10n, answer.authorRole),"""),
        ("""                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                      Gap(4),
                      Text("Foydali deb qabul qilingan", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),""",
         """                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 12, color: Colors.white),
                      const Gap(4),
                      Text(l10n.answerAcceptedBadge,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),"""),
        ("""                  label: const Text("Qabul qilish", style: TextStyle(fontSize: 11)),""",
         """                  label: Text(l10n.answerAcceptAction,
                      style: const TextStyle(fontSize: 11)),"""),
      ])

print("question detail OK")

"""LexHub l10n — BATCH 3c: feedlar, FAQ sahifasi, emergency, saqlangan keyslar.

§16 CARVE-OUT: `emergency_rights_page.dart` ichidagi `emergencyProtocols`
ro'yxati (4 sarlavha + 4 izoh + 14 huquqiy qoida) TARJIMA QILINMAYDI — bu
konstitutsiyaviy/qonuniy matn (maxsus content), UI chrome emas.
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from l10n_apply import apply_file  # noqa: E402

L10N = "import 'package:lexhub/core/localization/l10n.dart';"
CATLBL = "import 'package:lexhub/core/localization/category_labels.dart';"
ISDARK = "    final isDark = theme.brightness == Brightness.dark;"
STRINGS = "import 'package:lexhub/core/constants/app_strings.dart';\n"

SPEC = {
    # -------------------------------------------------------- recent cases feed
    'lib/features/home/presentation/widgets/recent_cases_feed.dart': {
        'imports': [CATLBL, L10N],
        'l10nAnchor': ISDARK,
        'constText': ['Murojaat Tahlili'],
        'raw': [
            ['                                child: Text(\n'
             '                                  item.category,',
             '                                child: Text(\n'
             '                                  homeCategoryLabel(l10n, item.category),'],
        ],
        'pairs': [
            ["Mening so'nggi murojaatlarim", 'l10n.recentCasesTitle'],
            ['Barchasi (${cases.length})', 'l10n.recentCasesSeeAll(cases.length)'],
            ['${item.legalBasis.length} ta Lex.uz moddasi',
             'l10n.legalBasisCount(item.legalBasis.length)'],
            ["O'qish", 'l10n.actionRead'],
            ['Murojaat Tahlili', 'context.l10n.recentCaseDetailTitle'],
        ],
    },
    # ----------------------------------------------------- trending questions
    'lib/features/home/presentation/widgets/trending_questions_feed.dart': {
        'imports': [CATLBL, L10N],
        'raw': [
            ['  void _showDetailModal(BuildContext context, SeedQuestionModel item) {\n'
             '    final theme = Theme.of(context);\n' + ISDARK,
             '  void _showDetailModal(BuildContext context, SeedQuestionModel item) {\n'
             '    final theme = Theme.of(context);\n' + ISDARK +
             '\n    final l10n = context.l10n;'],
            ['  Widget build(BuildContext context) {\n'
             '    final theme = Theme.of(context);\n' + ISDARK,
             '  Widget build(BuildContext context) {\n'
             '    final theme = Theme.of(context);\n' + ISDARK +
             '\n    final l10n = context.l10n;'],
            ['                          child: Text(\n'
             '                            item.categoryName,',
             '                          child: Text(\n'
             '                            homeCategoryLabel(l10n, item.categoryName),'],
            ['                        child: Text(\n'
             '                          item.categoryName,',
             '                        child: Text(\n'
             '                          homeCategoryLabel(l10n, item.categoryName),'],
        ],
        'pairs': [
            ["${item.viewsCount} marta ko'rildi",
             'l10n.viewsCountLong(item.viewsCount)'],
            ["Ushbu kategoriya bo'yicha savollar topilmadi",
             'l10n.trendingEmptyInCategory'],
            ["Ko'p beriladigan yuridik savollar", 'l10n.trendingTitle'],
            ['${questions.length} ta keys', 'l10n.casesCount(questions.length)'],
            ["Tahlilni o'qish", 'l10n.actionReadAnalysis'],
        ],
    },
}

total = 0
for path, spec in SPEC.items():
    total += apply_file(path, spec)
    print('OK ', path)
print('batch3-c replaced:', total)

"""LexHub l10n — BATCH 3d: FAQ sahifasi, emergency rights, saqlangan keyslar."""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from l10n_apply import apply_file  # noqa: E402

L10N = "import 'package:lexhub/core/localization/l10n.dart';"
CATLBL = "import 'package:lexhub/core/localization/category_labels.dart';"
ISDARK = "    final isDark = theme.brightness == Brightness.dark;"
STRINGS = "import 'package:lexhub/core/constants/app_strings.dart';\n"

SPEC = {
    # --------------------------------------------------------- FAQ sahifasi
    'lib/features/home/presentation/pages/faq_questions_page.dart': {
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
            ['label: const Text("Ushbu masala bo\'yicha AI maslahat olish"),',
             'label: Text(l10n.faqAskAiAction),'],
            ['label: const Text("Barchasi"),', 'label: Text(l10n.categoryAll),'],
            ['label: Text(cat.title),',
             'label: Text(homeCategoryLabel(l10n, cat.title)),'],
        ],
        # Ikkita kategoriya chipi; `initialCategory: item.categoryName` esa
        # QIYMAT bo'lib qoladi (Text( bilan mos kelmaydi).
        'regex': [
            [r'Text\(\n(\s+)item\.categoryName,',
             r'Text(\n\1homeCategoryLabel(l10n, item.categoryName),', 2],
        ],
        'pairs': [
            ["${item.viewsCount} marta ko'rildi",
             'l10n.viewsCountLong(item.viewsCount)'],
            ["Ko'p beriladigan savollar", 'l10n.faqBannerTitle'],
            ['Savollarni qidirish (masalan: aliment, jarima)...',
             'l10n.faqSearchHint'],
            ['${_filteredQuestions.length} ta yuridik keys',
             'l10n.faqLegalCasesCount(_filteredQuestions.length)'],
            ['Lex.uz moddalari bilan', 'l10n.faqWithLexUz'],
            ['Mos keluvchi savollar topilmadi', 'l10n.faqNoMatches'],
            ["Boshqa kalit so'z yoki toifani tanlab ko'ring",
             'l10n.faqNoMatchesHint'],
            ["${item.viewsCount} ko'rildi",
             'l10n.viewsCountShort(item.viewsCount)'],
            ["Tahlilni o'qish", 'l10n.actionReadAnalysis'],
        ],
    },
    # ------------------------------------------------------ emergency rights
    'lib/features/emergency_rights/presentation/pages/emergency_rights_page.dart': {
        'imports': [L10N],
        'l10nAnchor': ISDARK,
        'raw': [
            ['SnackBar(content: Text("Qo\'ng\'iroq qilib bo\'lmadi: $phone")),',
             'SnackBar(\n              content: Text(context.l10n.emergencyCallFailed(phone))),'],
            ['          AppStrings.emergencyRights,', '          l10n.emergencyRightsTitle,'],
        ],
        'pairs': [
            ['Tezkor Ishonch Telefonlari', 'l10n.emergencyHotlinesTitle'],
            ['Favqulodda Huquqiy Himoya Protokollari', 'l10n.emergencyProtocolsTitle'],
            ['Bosh Prokuratura', 'l10n.hotlineProsecutor'],
            ['Ichki Ishlar (IIV)', 'l10n.hotlineInterior'],
            ['Ombudsman', 'l10n.hotlineOmbudsman'],
            ['Mehnat Inspeksiyasi', 'l10n.hotlineLaborInspection'],
        ],
        'dropLines': [STRINGS],
    },
    # ---------------------------------------------------- saqlangan keyslar
    'lib/features/saved_cases/presentation/pages/saved_cases_page.dart': {
        'imports': [CATLBL, L10N],
        'raw': [
            ['    final theme = Theme.of(context);\n\n    return BlocProvider(',
             '    final theme = Theme.of(context);\n'
             '    final l10n = context.l10n;\n\n    return BlocProvider('],
            ['            AppStrings.savedCases,', '            l10n.savedCasesTitle,'],
            ['const Text(AppStrings.retry)', 'Text(l10n.actionRetry)'],
        ],
        'regex': [
            [r'Text\(\n(\s+)item\.category,',
             r'Text(\n\1homeCategoryLabel(l10n, item.category),', 1],
        ],
        'constText': ['Saqlangan Yuridik Keys'],
        'pairs': [
            ['Saqlangan keyslar mavjud emas', 'l10n.savedCasesEmptyTitle'],
            ["Yuridik maslahatlarni saqlab qo'yish orqali ularni internetsiz, "
             'istalgan vaqtda qayta ko\'rishingiz mumkin.', 'l10n.savedCasesEmptyBody'],
            ['Savol: \\"${item.userQuery}\\"',
             'l10n.savedCaseQuestionQuoted(item.userQuery)'],
            ['${item.legalBasis.length} ta Lex.uz moddasi',
             'l10n.legalBasisCount(item.legalBasis.length)'],
            ["Batafsil ko'rish", 'l10n.actionViewDetails'],
            ['Saqlangan Yuridik Keys', 'context.l10n.savedCaseDetailTitle'],
        ],
        'dropLines': [STRINGS],
    },
}

total = 0
for path, spec in SPEC.items():
    total += apply_file(path, spec)
    print('OK ', path)
print('batch3-d replaced:', total)

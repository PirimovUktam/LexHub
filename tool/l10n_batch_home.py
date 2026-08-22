"""LexHub l10n — BATCH 3: home + kabinet + feed + FAQ + saved cases.

`tool/l10n_apply.py` dagi `apply_file()` ni ishlatadi: har bir anchor/literal
FAQAT BIR MARTA almashtiriladi va topilmasa skript XATO bilan to'xtaydi.
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from l10n_apply import apply_file  # noqa: E402

L10N = "import 'package:lexhub/core/localization/l10n.dart';"
CATLBL = "import 'package:lexhub/core/localization/category_labels.dart';"
ISDARK = "    final isDark = theme.brightness == Brightness.dark;"

SPEC = {
    # ----------------------------------------------------------- home header
    'lib/features/home/presentation/widgets/home_header_widget.dart': {
        'imports': [L10N],
        'l10nAnchor': ISDARK,
        'pairs': [
            ['Assalomu alaykum', 'l10n.homeGreeting'],
            ['LexHub Platformasi', 'l10n.homePlatformTitle'],
            ['Muammoingizni oddiy tilda yozing...', 'l10n.homeQueryHint'],
            ['AI Tahlil', 'l10n.homeAiAnalyzeButton'],
        ],
    },
    # -------------------------------------------------- emergency quick tile
    'lib/features/home/presentation/widgets/emergency_quick_button.dart': {
        'imports': [L10N],
        'l10nAnchor': ISDARK,
        'pairs': [
            ['Tezkor Huquqiy Himoya', 'l10n.emergencyQuickTitle'],
            ["Hibs, tintuv, so'roq va 102/1002 ishonch raqamlari",
             'l10n.emergencyQuickSubtitle'],
        ],
    },
    # ------------------------------------------------------- FAQ entry banner
    'lib/features/home/presentation/widgets/faq_entry_banner.dart': {
        'imports': [L10N],
        'l10nAnchor': ISDARK,
        'pairs': [
            ["Ko'p beriladigan savollar", 'l10n.faqBannerTitle'],
            ['TOP 20+', 'l10n.faqBannerBadge'],
            ['Eng ommabop yuridik keyslar va tayyor yechimlar',
             'l10n.faqBannerSubtitle'],
            ['Barchasi', 'l10n.categoryAll'],
        ],
    },
    # ------------------------------------------------------- category grid
    'lib/features/home/presentation/widgets/category_grid_widget.dart': {
        'imports': [CATLBL, L10N],
        'l10nAnchor': ISDARK,
        'raw': [
            # `(13)` qattiq yozilgan edi — real son bilan almashtirildi.
            ['child: const Text("Barchasi", style: TextStyle(fontSize: 12)),',
             'child: Text(l10n.categoryAll,\n'
             '                    style: const TextStyle(fontSize: 12)),'],
            ['                      Text(\n                        cat.title,',
             '                      Text(\n'
             '                        homeCategoryLabel(l10n, cat.title),'],
        ],
        'pairs': [
            ['Huquqiy Kategoriyalar (13)',
             'l10n.homeCategoriesTitle(categories.length)'],
        ],
    },
}

total = 0
for path, spec in SPEC.items():
    total += apply_file(path, spec)
    print('OK ', path)
print('batch3-a replaced:', total)

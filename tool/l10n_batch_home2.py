"""LexHub l10n — BATCH 3b: home page, kabinet, feedlar, FAQ, emergency, saved.

Legal CONTENT (§16 "maxsus content") tarjima QILINMAYDI:
`emergency_rights_page.dart` ichidagi `emergencyProtocols` (4 sarlavha,
4 izoh, 14 qoida) — bu konstitutsiyaviy kafolatlar matni, UI chrome emas.
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from l10n_apply import apply_file  # noqa: E402

L10N = "import 'package:lexhub/core/localization/l10n.dart';"
CATLBL = "import 'package:lexhub/core/localization/category_labels.dart';"
ISDARK = "    final isDark = theme.brightness == Brightness.dark;"
STRINGS = "import 'package:lexhub/core/constants/app_strings.dart';\n"

CONST_TEXT_UZ = None
NEW_TEXT_UZ = None

SPEC = {
    # ------------------------------------------------------------- home page
    'lib/features/home/presentation/pages/home_page.dart': {
        'imports': [L10N],
        'l10nAnchor': ISDARK,
        'constText': [
            'Davlat xizmatlari va Jarayoni',
            'Sizda ham huquqiy savol bormi?',
        ],
        'pairs': [
            ['Davlat xizmatlari va Jarayoni', 'l10n.homeServicesBannerTitle'],
            ['Sizda ham huquqiy savol bormi?', 'l10n.homeAskBannerTitle'],
            ["my.gov.uz yo'riqnomalari, to'lovlar va rasmiy muddatlar",
             'l10n.homeServicesBannerSubtitle'],
            ['Mavzuga oid masalalar', 'l10n.homeTopicMatters'],
            ['Hamjamiyat Savollari', 'l10n.homeCommunityQuestions'],
            ['Privacy Guard: 100% himoyalangan', 'l10n.homePrivacyGuardBadge'],
            ["Shaxsiy ma'lumotlaringiz yashirilgan holda savol yo'llang",
             'l10n.homeAskBannerSubtitle'],
        ],
    },
    # ------------------------------------------------------- shaxsiy kabinet
    'lib/features/saved_cases/presentation/pages/documents_and_saved_hub_page.dart': {
        'imports': [L10N],
        'raw': [
            ['    final isDark = Theme.of(context).brightness == Brightness.dark;',
             '    final isDark = Theme.of(context).brightness == Brightness.dark;\n'
             '    final l10n = context.l10n;'],
            ['          title: const Text(\n            "Shaxsiy Kabinet",\n'
             '            style: TextStyle(fontWeight: FontWeight.w800),',
             '          title: Text(\n            l10n.cabinetTitle,\n'
             '            style: const TextStyle(fontWeight: FontWeight.w800),'],
            ['            tabs: const [\n              Tab(\n'
             '                icon: Icon(Icons.person_outline_rounded),\n'
             '                text: "Profil",\n              ),\n'
             '              Tab(\n'
             '                icon: Icon(Icons.event_available_rounded),\n'
             '                text: "Konsultatsiyalar",\n              ),\n'
             '              Tab(\n'
             '                icon: Icon(Icons.description_outlined),\n'
             '                text: "Konstruktor",\n              ),\n'
             '              Tab(\n'
             '                icon: Icon(Icons.bookmark_outline_rounded),\n'
             '                text: "Oflayn Keyslar",\n              ),\n'
             '            ],',
             '            tabs: [\n              Tab(\n'
             '                icon: const Icon(Icons.person_outline_rounded),\n'
             '                text: l10n.cabinetTabProfile,\n              ),\n'
             '              Tab(\n'
             '                icon: const Icon(Icons.event_available_rounded),\n'
             '                text: l10n.cabinetTabConsultations,\n              ),\n'
             '              Tab(\n'
             '                icon: const Icon(Icons.description_outlined),\n'
             '                text: l10n.cabinetTabBuilder,\n              ),\n'
             '              Tab(\n'
             '                icon: const Icon(Icons.bookmark_outline_rounded),\n'
             '                text: l10n.cabinetTabOfflineCases,\n              ),\n'
             '            ],'],
        ],
        'pairs': [],
    },
}

total = 0
for path, spec in SPEC.items():
    total += apply_file(path, spec)
    print('OK ', path)
print('batch3-b replaced:', total)

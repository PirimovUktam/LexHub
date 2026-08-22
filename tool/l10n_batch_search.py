"""LexHub l10n — BATCH 5: global qidiruv (search) yuzasi.

`search_page.dart` ichidagi barcha foydalanuvchiga ko'rinadigan hardcoded
o'zbek matnlari `AppL10n` kalitlariga o'tkaziladi.

MUHIM (regress qilmaslik uchun):
  * `query: "Aliment" / "Mehnat" / "Iste'molchi" / "Jarima"` — bu QIDIRUV
    QIYMATLARI (SearchQueryChangedEvent ga ketadi), TARJIMA QILINMAYDI.
  * `SearchResultType` ning xom qiymatlari (`law`, `expert`, ...) — kontrakt.
  * `item.subtitle!` / `item.costBhmPercent` chiqishi o'zgarmaydi.
"""
import sys

from l10n_apply import apply_file

L10N = "import 'package:lexhub/core/localization/l10n.dart';"
SLBL = "import 'package:lexhub/core/localization/search_labels.dart';"

F = 'lib/features/search/presentation/pages/search_page.dart'


def sig(name: str, args: str) -> tuple[str, str]:
    """Helper metod ichiga `final l10n = context.l10n;` qo'shadi."""
    head = f'  Widget _build{name}({args}) {{\n'
    return head, head + '    final l10n = context.l10n;\n'


def badge(icon: str, literal: str, key: str) -> tuple[str, str]:
    """`child: const Row([...Text("literal")])` -> de-const + l10n."""
    old = (
        '                child: const Row(\n'
        '                  children: [\n'
        f'                    {icon}\n'
        '                    Gap(4),\n'
        '                    Text(\n'
        f'                      "{literal}",\n'
        '                      style: TextStyle(\n'
    )
    new = (
        '                child: Row(\n'
        '                  children: [\n'
        f'                    const {icon}\n'
        '                    const Gap(4),\n'
        '                    Text(\n'
        f'                      {key},\n'
        '                      style: const TextStyle(\n'
    )
    return old, new


CARD_ARGS = 'BuildContext context, SearchResultItem item, bool isDark'
STATE_ARGS = 'BuildContext context, SearchState state, bool isDark'

SPEC = {
    F: {
        'imports': [L10N, SLBL],
        'raw': [
            # --- helper metodlarga l10n kiritish ---
            sig('SearchInputField', STATE_ARGS),
            sig('FilterChipsBar', STATE_ARGS),
            sig('Body', STATE_ARGS),
            sig('InitialHistoryView', STATE_ARGS),
            sig('LawResultCard', CARD_ARGS),
            sig('ExpertResultCard', CARD_ARGS),
            sig('ServiceResultCard', CARD_ARGS),
            sig('TemplateResultCard', CARD_ARGS),
            sig('QuestionResultCard', CARD_ARGS),
            sig('EmptyState', 'BuildContext context, bool isDark'),

            # --- filtr chip yorlig'i (enum'dan ko'chirilgan) ---
            ('              filter.label,\n',
             '              searchResultTypeLabel(l10n, filter),\n'),

            # --- "Tozalash" (const Text) ---
            ('child: const Text("Tozalash", style: TextStyle(fontSize: 12)),',
             'child: Text(l10n.actionClear, style: const TextStyle(fontSize: 12)),'),

            # --- 4 ta natija kartasi badge'i (const Row de-const) ---
            badge('Icon(Icons.gavel_rounded, size: 12, color: AppColors.indigo),',
                  'Qonun hujjati', 'l10n.searchBadgeLaw'),
            badge('Icon(Icons.account_balance_rounded, size: 12, color: AppColors.amber),',
                  'Davlat xizmati', 'l10n.searchBadgeService'),
            badge('Icon(Icons.description_rounded, size: 12, color: AppColors.crimson),',
                  'Hujjat shabloni', 'l10n.searchBadgeTemplate'),
            badge('Icon(Icons.forum_rounded, size: 12, color: AppColors.primary),',
                  'Hamjamiyat forumi', 'l10n.searchBadgeQuestion'),

            # --- Lex.uz badge (const Text) ---
            ('                const Text(\n'
             '                  "Lex.uz ↗",\n'
             '                  style: TextStyle(\n',
             '                Text(\n'
             '                  l10n.searchLexUzBadge,\n'
             '                  style: const TextStyle(\n'),

            # --- "Rasmiy yurist" (const Text) ---
            ('                      child: const Text(\n'
             '                        "Rasmiy yurist",\n'
             '                        style: TextStyle(fontSize: 10,',
             '                      child: Text(\n'
             '                        l10n.searchOfficialLawyer,\n'
             '                        style: const TextStyle(fontSize: 10,'),

            # --- "Bepul" (const Text) ---
            ('                  child: const Text(\n'
             '                    "Bepul",\n'
             '                    style: TextStyle(fontSize: 11,',
             '                  child: Text(\n'
             '                    l10n.statusFree,\n'
             '                    style: const TextStyle(fontSize: 11,'),

            # --- "Konstruktor ⚡" (const Text) ---
            ('              const Text(\n'
             '                "Konstruktor ⚡",\n'
             '                style: TextStyle(\n',
             '              Text(\n'
             '                l10n.searchBuilderBadge,\n'
             '                style: const TextStyle(\n'),

            # --- bo'sh natija sarlavhasi (const Text) ---
            ('            const Text(\n'
             '              "Hech qanday natija topilmadi",\n'
             '              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),\n',
             '            Text(\n'
             '              l10n.searchEmptyTitle,\n'
             '              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),\n'),
        ],
        'pairs': [
            ['Qonun, advokat, xizmat yoki shablon...', 'l10n.searchHint'],
            ['Qidiruvda xatolik yuz berdi', 'l10n.searchError'],
            ["So'nggi qidiruvlar", 'l10n.searchRecentTitle'],
            ['Ommabop huquqiy mavzular', 'l10n.searchPopularTitle'],

            # Ommabop mavzular: FAQAT title/subtitle tarjima qilinadi,
            # `query:` qiymatlari xom holda qoladi.
            ['Aliment undirish tartibi', 'l10n.searchTopicAlimonyTitle'],
            ["Oila kodeksi 96-moddasi va sud buyrug'i arizasi",
             'l10n.searchTopicAlimonySubtitle'],
            ["Noqonuniy ishdan bo'shatish", 'l10n.searchTopicDismissalTitle'],
            ["Mehnat kodeksi kafolatlari va tiklash da'vosi",
             'l10n.searchTopicDismissalSubtitle'],
            ['Sifatsiz tovar pulini qaytarish', 'l10n.searchTopicRefundTitle'],
            ["Iste'molchilar huquqlarini himoya qilish qonuni",
             'l10n.searchTopicRefundSubtitle'],
            ["Yo'l harakati jarimalari ustidan shikoyat",
             'l10n.searchTopicFineTitle'],
            ['YPX qarorlari ustidan apellyatsiya berish',
             'l10n.searchTopicFineSubtitle'],

            # Xizmat narxi: chiqish formati o'zgarmaydi ("5.0% BHM").
            [r'${item.costBhmPercent}% BHM',
             'l10n.searchCostBhmPercent(item.costBhmPercent.toString())'],

            # `if (item.subtitle != null)` guard ichida — fayldagi mavjud uslub.
            [r'Organ: ${item.subtitle}',
             'l10n.searchTemplateAuthority(item.subtitle!)'],

            [r'${item.answersCount} ta javob',
             'l10n.communityAnswersCount(item.answersCount)'],

            ["Boshqa kalit so'zlar bilan qidirib ko'ring yoki boshqa toifa filtrini tanlang.",
             'l10n.searchEmptyBody'],
        ],
    },
}


def main() -> None:
    total, failed = 0, []
    for path, spec in SPEC.items():
        try:
            n = apply_file(path, spec)
        except SystemExit as exc:
            print(f'FAIL {path}\n     {exc}')
            failed.append(path)
            continue
        total += n
        print(f'OK  {path}  ({n})')
    print(f'TOTAL pairs replaced: {total} | files OK: {len(SPEC) - len(failed)}')
    if failed:
        sys.exit(1)


if __name__ == '__main__':
    main()

"""LexHub l10n — BATCH 6: Davlat xizmatlari + Hujjatlar konstruktori.

Qamrov (5 fayl):
  * citizen_services_page.dart
  * service_detail_page.dart
  * document_templates_page.dart
  * document_generator_page.dart
  * document_preview_page.dart

MUHIM (regress qilmaslik uchun, §1/§16):
  * `CitizenServicesPage.categories` va `DocumentTemplatesPage.categories`
    ichidagi XOM o'zbek qiymatlari O'ZGARMAYDI — ular
    `FilterServicesByCategoryEvent(cat)` / `LoadTemplatesListEvent(category:)`
    ga QIYMAT sifatida ketadi va `service.category` / `template.category`
    bilan solishtiriladi. Ekranda ko'rinadigan matn faqat
    `catalogCategoryLabel(l10n, ...)` orqali tarjima qilinadi.
  * `step.stepType == 'online' / 'payment' / 'appeal'` — DB qiymatlari,
    faqat BADGE matni tarjima qilinadi.
  * "Lex.uz" / "my.gov.uz" — brend/domen, tarjima qilinmaydi.
  * `document_preview_page.dart` ichidagi SAQLANADIGAN kontent
    (`relatableSummary`, `actionableSteps`, `articleNumber: "Asosiy norma"`,
    `RiskAssessment.summary`) — Hive/Supabase'ga yoziladigan MA'LUMOT,
    UI chrome emas (§16 "maxsus content"), shuning uchun tegilmaydi.
"""
import sys

from l10n_apply import apply_file

L10N = "import 'package:lexhub/core/localization/l10n.dart';"
CATLBL = "import 'package:lexhub/core/localization/category_labels.dart';"
APPSTR = "import 'package:lexhub/core/constants/app_strings.dart';\n"

SVC_LIST = 'lib/features/citizen_services/presentation/pages/citizen_services_page.dart'
SVC_DET = 'lib/features/citizen_services/presentation/pages/service_detail_page.dart'
TPL_LIST = 'lib/features/document_builder/presentation/pages/document_templates_page.dart'
DOC_GEN = 'lib/features/document_builder/presentation/pages/document_generator_page.dart'
DOC_PRE = 'lib/features/document_builder/presentation/pages/document_preview_page.dart'


def popular(indent: int, icon_size: int, font_size: int) -> tuple[str, str]:
    """`child: const Row([... Text("Mashhur")])` -> de-const + l10n."""
    p = ' ' * indent
    old = (
        f'{p}child: const Row(\n'
        f'{p}  mainAxisSize: MainAxisSize.min,\n'
        f'{p}  children: [\n'
        f'{p}    Icon(Icons.star_rounded, size: {icon_size}, color: AppColors.amberDark),\n'
        f'{p}    Gap(2),\n'
        f'{p}    Text(\n'
        f'{p}      "Mashhur",\n'
        f'{p}      style: TextStyle(\n'
        f'{p}        color: AppColors.amberDark,\n'
        f'{p}        fontWeight: FontWeight.bold,\n'
        f'{p}        fontSize: {font_size},\n'
    )
    new = (
        f'{p}child: Row(\n'
        f'{p}  mainAxisSize: MainAxisSize.min,\n'
        f'{p}  children: [\n'
        f'{p}    const Icon(Icons.star_rounded, size: {icon_size}, color: AppColors.amberDark),\n'
        f'{p}    const Gap(2),\n'
        f'{p}    Text(\n'
        f'{p}      l10n.badgePopular,\n'
        f'{p}      style: const TextStyle(\n'
        f'{p}        color: AppColors.amberDark,\n'
        f'{p}        fontWeight: FontWeight.bold,\n'
        f'{p}        fontSize: {font_size},\n'
    )
    return old, new


def step_badge(literal: str, key: str, color: str) -> tuple[str, str]:
    """Bosqich turi badge'i: `const Text("Onlayn", style: TextStyle(...))`."""
    style = f'fontSize: 10, color: {color}, fontWeight: FontWeight.bold'
    return (f'child: const Text("{literal}", style: TextStyle({style})),',
            f'child: Text({key}, style: const TextStyle({style})),')


SPEC = {
    SVC_LIST: {
        'imports': [L10N, CATLBL],
        'raw': [
            ('  Widget build(BuildContext context) {\n'
             '    final theme = Theme.of(context);\n'
             '    final isDark = theme.brightness == Brightness.dark;\n'
             '\n'
             '    return BlocProvider(\n',
             '  Widget build(BuildContext context) {\n'
             '    final theme = Theme.of(context);\n'
             '    final isDark = theme.brightness == Brightness.dark;\n'
             '    final l10n = context.l10n;\n'
             '\n'
             '    return BlocProvider(\n'),

            ('  Widget _buildServiceCard(BuildContext context, CitizenService service, bool isDark) {\n'
             '    final theme = Theme.of(context);\n',
             '  Widget _buildServiceCard(BuildContext context, CitizenService service, bool isDark) {\n'
             '    final theme = Theme.of(context);\n'
             '    final l10n = context.l10n;\n'),

            ('                AppStrings.citizenServicesTitle,\n',
             '                l10n.servicesTitle,\n'),

            ('child: const Text(AppStrings.retry),',
             'child: Text(l10n.actionRetry),'),

            # filtr chip yorlig'i (QIYMAT `cat` o'zgarmaydi)
            ('                        label: Text(\n'
             '                          cat,\n',
             '                        label: Text(\n'
             '                          catalogCategoryLabel(l10n, cat),\n'),

            # kartadagi kategoriya yorlig'i
            ('                  child: Text(\n'
             '                    service.category,\n',
             '                  child: Text(\n'
             '                    catalogCategoryLabel(l10n, service.category),\n'),

            popular(20, 12, 10),
        ],
        'pairs': [
            ["Davlat xizmatlari yoki qo'llanmalarni qidirish...", 'l10n.servicesSearchHint'],
            ['Xizmatlar topilmadi', 'l10n.servicesEmptyTitle'],
            [r'${service.processingDays} kun',
             'l10n.serviceDaysShort(service.processingDays)'],
        ],
        'dropLines': [APPSTR],
    },

    SVC_DET: {
        'imports': [L10N, CATLBL],
        'raw': [
            ('          const SnackBar(content: Text("Havolani ochib bo\'lmadi")),',
             '          SnackBar(content: Text(context.l10n.errorCannotOpenLink)),'),

            ('  Widget build(BuildContext context) {\n'
             '    final theme = Theme.of(context);\n'
             '    final isDark = theme.brightness == Brightness.dark;\n'
             '\n'
             '    return Scaffold(\n',
             '  Widget build(BuildContext context) {\n'
             '    final theme = Theme.of(context);\n'
             '    final isDark = theme.brightness == Brightness.dark;\n'
             '    final l10n = context.l10n;\n'
             '\n'
             '    return Scaffold(\n'),

            ('                  child: Text(\n'
             '                    service.category,\n',
             '                  child: Text(\n'
             '                    catalogCategoryLabel(l10n, service.category),\n'),

            # BHM badge (1-uchrash) — chiqish formati o'zgarmaydi
            ('                    child: Text(\n'
             '                      "${service.costBhmPercent} BHM",\n'
             '                      style: const TextStyle(\n',
             '                    child: Text(\n'
             '                      l10n.serviceCostBhm(service.costBhmPercent.toString()),\n'
             '                      style: const TextStyle(\n'),

            ('                        const Text(\n'
             '                          "O\'zbekiston Qonunchiligi asosida tasdiqlangan",\n'
             '                          style: TextStyle(\n',
             '                        Text(\n'
             '                          l10n.serviceVerifiedByLaw,\n'
             '                          style: const TextStyle(\n'),

            ('                          service.lastVerifiedAt != null\n'
             '                              ? "Oxirgi tekshiruv: ${service.lastVerifiedAt!.year}-yil ${service.lastVerifiedAt!.month}-oy"\n'
             '                              : "Qonunchilik yangilanishi: Faol",\n',
             '                          service.lastVerifiedAt != null\n'
             '                              ? l10n.serviceLastVerified(\n'
             '                                  service.lastVerifiedAt!.year,\n'
             '                                  service.lastVerifiedAt!.month,\n'
             '                                )\n'
             '                              : l10n.serviceLawUpdateActive,\n'),

            ('Text(AppStrings.processingTime, style:',
             'Text(l10n.serviceProcessingTime, style:'),

            ('                          "${service.processingDays} ish kuni",\n',
             '                          l10n.serviceWorkDays(service.processingDays),\n'),

            ('Text(AppStrings.serviceFee, style:',
             'Text(l10n.serviceFeeLabel, style:'),

            ('                          service.isFree ? "To\'lovsiz" : "${service.costBhmPercent} BHM",\n',
             '                          service.isFree\n'
             '                              ? l10n.serviceNoFee\n'
             '                              : l10n.serviceCostBhm(service.costBhmPercent.toString()),\n'),

            ('                AppStrings.requiredDocs,\n',
             '                l10n.serviceRequiredDocsTitle,\n'),

            step_badge('Onlayn', 'l10n.serviceStepOnline', 'AppColors.indigo'),
            step_badge("To'lov", 'l10n.serviceStepPayment', 'AppColors.emerald'),
            step_badge('Shikoyat', 'l10n.serviceStepAppeal', 'AppColors.amberDark'),

            ('label: const Text("Ushbu bosqichni portalda bajarish"),',
             'label: Text(l10n.serviceStepOpenPortal),'),

            ('label: const Text(AppStrings.openMyGov),',
             'label: Text(l10n.serviceOpenMyGov),'),
        ],
        'pairs': [
            ["Xizmat qo'llanmasi", 'l10n.serviceGuideTitle'],
            ['Bepul xizmat', 'l10n.serviceFreeBadge'],
            ['Tavsif va Maqsad', 'l10n.serviceDescriptionTitle'],
            ['Rasmiy Huquqiy Asos', 'l10n.serviceLegalBasisTitle'],
            ['Bosqichma-bosqich harakatlar', 'l10n.serviceStepsTitle'],
        ],
        'dropLines': [APPSTR],
    },

    TPL_LIST: {
        'imports': [L10N, CATLBL],
        'raw': [
            ('  Widget build(BuildContext context) {\n'
             '    final theme = Theme.of(context);\n'
             '    final isDark = theme.brightness == Brightness.dark;\n'
             '\n'
             '    return BlocProvider(\n',
             '  Widget build(BuildContext context) {\n'
             '    final theme = Theme.of(context);\n'
             '    final isDark = theme.brightness == Brightness.dark;\n'
             '    final l10n = context.l10n;\n'
             '\n'
             '    return BlocProvider(\n'),

            ('                        label: Text(\n'
             '                          cat,\n',
             '                        label: Text(\n'
             '                          catalogCategoryLabel(l10n, cat),\n'),

            ('child: const Text("Qayta yuklash"),',
             'child: Text(l10n.actionReload),'),

            ('                                                    child: Text(\n'
             '                                                      template.category,\n',
             '                                                    child: Text(\n'
             '                                                      catalogCategoryLabel(l10n, template.category),\n'),

            popular(54, 10, 9),
        ],
        'pairs': [
            ['Hujjatlar Konstruktori', 'l10n.documentBuilderTitle'],
            ['Shablon nomi, modda yoki sohani qidirish...', 'l10n.templatesSearchHint'],
            ['Shablonlar topilmadi', 'l10n.templatesEmptyTitle'],
            [r'${template.fields.length} ta maydon',
             'l10n.templateFieldsCount(template.fields.length)'],
        ],
    },

    DOC_GEN: {
        'imports': [L10N],
        'raw': [
            ('  Widget build(BuildContext context) {\n'
             '    final theme = Theme.of(context);\n'
             '\n'
             '    return BlocProvider(\n',
             '  Widget build(BuildContext context) {\n'
             '    final theme = Theme.of(context);\n'
             '    final l10n = context.l10n;\n'
             '\n'
             '    return BlocProvider(\n'),

            ('label: const Text("Hujjatni shakllantirish va ko\'rish"),',
             'label: Text(l10n.documentGenerateAction),'),
        ],
        'pairs': [
            ['Rasmiy Yuridik Asos:', 'l10n.documentLegalBasisLabel'],
            ["Maydonlarni to'ldiring:", 'l10n.documentFillFieldsTitle'],
        ],
    },

    DOC_PRE: {
        'imports': [L10N],
        'raw': [
            ('      const SnackBar(\n'
             '        content: Text("Hujjat matni xotiraga nusxalandi!"),\n'
             '        duration: Duration(seconds: 2),\n'
             '      ),\n',
             '      SnackBar(\n'
             '        content: Text(context.l10n.documentCopiedSnack),\n'
             '        duration: const Duration(seconds: 2),\n'
             '      ),\n'),

            ('        const SnackBar(\n'
             '          content: Text("Hujjat muvaffaqiyatli saqlandi!"),\n'
             '          backgroundColor: AppColors.emeraldDark,\n'
             '          duration: Duration(seconds: 2),\n'
             '        ),\n',
             '        SnackBar(\n'
             '          content: Text(context.l10n.documentSavedSnack),\n'
             '          backgroundColor: AppColors.emeraldDark,\n'
             '          duration: const Duration(seconds: 2),\n'
             '        ),\n'),

            ('  Widget build(BuildContext context) {\n'
             '    final theme = Theme.of(context);\n'
             '    final isDark = theme.brightness == Brightness.dark;\n'
             '\n'
             '    return Scaffold(\n',
             '  Widget build(BuildContext context) {\n'
             '    final theme = Theme.of(context);\n'
             '    final isDark = theme.brightness == Brightness.dark;\n'
             '    final l10n = context.l10n;\n'
             '\n'
             '    return Scaffold(\n'),

            # pastdagi tugma: "Nusxalash" ning 2-uchrashi (tooltip'dan keyin
            # `pairs` 1-uchrashini oladi, shuning uchun bu YERDA birinchi).
            ('label: const Text("Nusxalash"),',
             'label: Text(l10n.actionCopy),'),

            ('label: Text(_isSaved ? "Saqlandi" : "Saqlash"),',
             'label: Text(_isSaved ? l10n.actionSaved : l10n.actionSave),'),
        ],
        'pairs': [
            ["Tayyor Hujjat Ko'rinishi", 'l10n.documentPreviewTitle'],
            ["Saqlanganlarga qo'shish", 'l10n.documentSaveTooltip'],
            ['Nusxalash', 'l10n.actionCopy'],
            [r'Yuridik Asos: ${widget.template.legalBasisSummary}',
             'l10n.documentLegalBasisWith(widget.template.legalBasisSummary)'],
            ['Rasmiy talablar asosida shakllantirilgan. Chop etishga tayyor.',
             'l10n.documentReadyToPrint'],
            ["Lex.uz da ko'rish", 'l10n.actionViewOnLexUz'],
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

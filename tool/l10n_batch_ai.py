"""LexHub — LOCALIZATION BATCH 4: Legal AI (LexHub AI) sahifasi va widgetlari.

Ishga tushirish (repo root'dan):
    python tool/l10n_batch_ai.py            # barcha fayllar
    python tool/l10n_batch_ai.py risk_matrix  # faqat mos kelgan fayllar

QOIDALAR (§16):
  * FAQAT ekranda ko'rinadigan matn `l10n.*` ga ko'chiriladi.
  * `chip['label']` qiymati SO'ROV KATEGORIYASI sifatida ham ketadi
    (`SubmitLegalQueryEvent.category`), shuning uchun XOM qiymat saqlanadi;
    faqat ko'rinishi `legalAiChipLabel()` orqali tarjima qilinadi.
  * `RiskLevel` enum'ining `@JsonValue` kontrakti tegilmaydi; yorliq
    `riskLevelLabel()` dan olinadi.
  * Konstitutsiya matnining AYNAN KELTIRILGAN sitatalari (Miranda dialogidagi
    28-modda matni va rasmiy so'z) TARJIMA QILINMAYDI — bu huquqiy content.
"""
import sys

from l10n_apply import apply_file

L10N = "import 'package:lexhub/core/localization/l10n.dart';"
AILBL = "import 'package:lexhub/core/localization/legal_ai_labels.dart';"
DROP_AS = "import 'package:lexhub/core/constants/app_strings.dart';\n"
ISDARK = '    final isDark = theme.brightness == Brightness.dark;'

P = 'lib/features/legal_assistant/presentation/pages/'
W = 'lib/features/legal_assistant/presentation/widgets/'

SPEC: dict[str, dict] = {}

# ---------------------------------------------------------------- main page
SPEC[P + 'legal_assistant_page.dart'] = {
    'imports': [L10N, AILBL],
    'l10nAnchor': ISDARK,
    'raw': [
        ('content: const Text(AppStrings.queryEmptyError),',
         'content: Text(context.l10n.aiQueryEmptyError),'),
        ("""const SnackBar(content: Text("To'liq huquqiy tahlil nusxalandi!")),""",
         'SnackBar(content: Text(context.l10n.aiFullAnalysisCopied)),'),
        ('AppStrings.appName,', 'l10n.appName,'),
        ('tooltip: AppStrings.savedCases,', 'tooltip: l10n.savedCasesTitle,'),
        ('hintText: AppStrings.askQuestionHint,', 'hintText: l10n.aiQueryHint,'),
        (': AppStrings.getAdviceButton,', ': l10n.aiGetAdviceButton,'),
        ("label: Text(chip['label']!, style: const TextStyle(fontSize: 11)),",
         "label: Text(legalAiChipLabel(l10n, chip['label']!),\n"
         '                              style: const TextStyle(fontSize: 11)),'),
        ('AppStrings.legalDisclaimer,', 'l10n.legalDisclaimer,'),
        ('label: const Text(AppStrings.copyAdvice),',
         'label: Text(l10n.actionCopyAnalysis),'),
        ('label: const Text("Ariza shakllantirish"),',
         'label: Text(l10n.aiBuildDocumentAction),'),
    ],
    'pairs': [
        ("O'zbekiston huquqiy tahlilchisi", 'l10n.aiAnalystSubtitle'),
        ('Huquqiy vaziyatingizni yozing', 'l10n.aiWriteSituationTitle'),
        ('Lex.uz moddalari tahlil qilinmoqda...', 'l10n.aiAnalyzingLexUz'),
        ("Ko'p uchraydigan huquqiy vaziyatlar", 'l10n.aiCommonSituations'),
    ],
    'dropLines': [DROP_AS],
}

# ------------------------------------------------------- action steps timeline
SPEC[W + 'action_steps_timeline.dart'] = {
    'imports': [L10N],
    'l10nAnchor': ISDARK,
    'raw': [('AppStrings.actionableStepsTitle,', 'l10n.aiStepsTitle,')],
    'pairs': [
        ('$totalCount tadan $completedCount tasi bajarildi',
         'l10n.aiStepsProgress(completedCount, totalCount)'),
    ],
    'dropLines': [DROP_AS],
}

# --------------------------------------------------------- clarification card
SPEC[W + 'ai_clarification_card.dart'] = {
    'imports': [L10N],
    'l10nAnchor': ISDARK,
    'raw': [('AppStrings.clarificationTitle,', 'l10n.aiClarificationTitle,')],
    'pairs': [
        ("Vaziyatingizga yanada aniq va to'g'ri qonuniy maslahat berish uchun "
         'quyidagi tafsilotlarni kiritish tavsiya etiladi:',
         'l10n.aiClarificationBody'),
    ],
    'dropLines': [DROP_AS],
}

# ------------------------------------------------------- relatable summary card
SPEC[W + 'relatable_summary_card.dart'] = {
    'imports': [L10N],
    'l10nAnchor': ISDARK,
    'raw': [
        ('''const SnackBar(
        content: Text("Xulosa matni nusxalandi!"),
        duration: Duration(seconds: 2),''',
         '''SnackBar(
        content: Text(context.l10n.aiSummaryCopied),
        duration: const Duration(seconds: 2),'''),
        ('AppStrings.relatableSummaryTitle,', 'l10n.aiSummaryTitle,'),
    ],
    'pairs': [
        ('Audio eshittirish boshlandi (Ovozli tahlil)...',
         'context.l10n.aiAudioStarted'),
        ("Audio to'xtatildi", 'context.l10n.aiAudioStopped'),
        ('Yuridik jargonsiz sodda tushuntirish', 'l10n.aiSummarySubtitle'),
        ('Ovozli tinglash', 'l10n.actionListenAudio'),
        ('Nusxalash', 'l10n.actionCopy'),
    ],
    'dropLines': [DROP_AS],
}

# --------------------------------------------------------- legal basis accordion
SPEC[W + 'legal_basis_accordion.dart'] = {
    'imports': [L10N],
    'l10nAnchor': ISDARK,
    'raw': [
        ("""const SnackBar(content: Text("Lex.uz havolasini ochib bo'lmadi")),""",
         'SnackBar(content: Text(context.l10n.aiLexUzOpenFailed)),'),
        ('content: Text("${article.articleNumber} matni nusxalandi!"),',
         'content: Text(context.l10n.aiArticleCopied(article.articleNumber)),'),
        ('AppStrings.legalBasisTitle,', 'l10n.aiLegalBasisTitle,'),
        ('label: const Text("Nusxalash", style: TextStyle(fontSize: 12)),',
         'label: Text(l10n.actionCopy, style: const TextStyle(fontSize: 12)),'),
        ('label: const Text(\n', 'label: Text(\n'),
        ('AppStrings.openLexUz,', 'l10n.actionOpenLexUz,'),
        ('style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),',
         'style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),'),
    ],
    'pairs': [
        ('Lex.uz rasmiy qonunchilik bazasi', 'l10n.aiLexUzBaseSubtitle'),
        ('Active', 'l10n.statusInForce'),
    ],
    'dropLines': [DROP_AS],
}
# ------------------------------------------------------------ risk matrix gauge
SPEC[W + 'risk_matrix_gauge.dart'] = {
    'imports': [L10N, AILBL],
    'l10nAnchor': ISDARK,
    'raw': [
        ('AppStrings.riskAssessmentTitle,', 'l10n.aiRiskTitle,'),
        ('assessment.level.displayName,', 'riskLevelLabel(l10n, assessment.level),'),
    ],
    'pairs': [
        ('Xolis huquqiy tahlil & cheklovlar', 'l10n.aiRiskSubtitle'),
        ("Xavf darajasi ko'rsatkichi", 'l10n.aiRiskGaugeLabel'),
        ('Past xavf', 'l10n.riskScaleLow'),
        ("O'rtacha", 'l10n.riskScaleMedium'),
        ('Yuqori', 'l10n.riskScaleHigh'),
        ('Kritik', 'l10n.riskScaleCritical'),
        ('Murojaat qilish uchun qolgan taxminiy muddat: '
         '${assessment.deadlineDays} kun',
         'l10n.aiDeadlineRemaining(assessment.deadlineDays ?? 0)'),
        ('Muhim cheklovlar va ogohlantirishlar:', 'l10n.aiLimitationsTitle'),
        ("Ushbu ish bo'yicha mustaqil harakat qilish yutqazish xavfini "
         'oshiradi. Malakali advokat bilan shartnoma tuzish tavsiya etiladi.',
         'l10n.aiLawyerRequiredWarning'),
    ],
    'dropLines': [DROP_AS],
}

# ------------------------------------------------------- emergency banner widget
SPEC[W + 'emergency_banner_widget.dart'] = {
    'imports': [L10N],
    'l10nAnchor': ISDARK,
    'raw': [
        # dialog metodida `l10n` e'lon qilinadi (build'dagi anchor'dan boshqa)
        ('''  void _showMirandaDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;''',
         '''  void _showMirandaDialog(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;'''),
        ("""content: Text("Qo'ng'iroq qilib bo'lmadi: $phone"),""",
         'content: Text(context.l10n.emergencyCallFailed(phone)),'),
        ('''        title: Row(
          children: const [
            Icon(Icons.security_rounded, color: AppColors.emergency),
            Gap(10),
            Expanded(
              child: Text(
                "Miranda Qoidasi",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),''',
         '''        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: AppColors.emergency),
            const Gap(10),
            Expanded(
              child: Text(
                l10n.emergencyMirandaTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),'''),
        ('''            const Text(
              "O'zbekiston Respublikasi Konstitutsiyasi 28-moddasi:",
              style: TextStyle(fontWeight: FontWeight.bold),''',
         '''            Text(
              l10n.emergencyMirandaArticleLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),'''),
        ('child: const Text("Tushundim"),', 'child: Text(l10n.actionOk),'),
        ('AppStrings.emergencyAlertTitle,', 'l10n.aiEmergencyAlertTitle,'),
        ('''                    label: const Text(
                      "Miranda Qoidasi",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),''',
         '''                    label: Text(
                      l10n.emergencyMirandaTitle,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),'''),
    ],
    'pairs': [
        ("Tergovchi yoki xodimga aytiladigan rasmiy so'z:",
         'l10n.emergencyMirandaScriptLabel'),
        ('Xavfli holatlar (Red Flags):', 'l10n.emergencyRedFlagsTitle'),
        ('Zudlik bilan nima qilish kerak:', 'l10n.emergencyImmediateActionsTitle'),
        ("Qo'ng'iroq (${protocol.emergencyHotline})",
         'l10n.emergencyCallAction(protocol.emergencyHotline)'),
    ],
    'dropLines': [DROP_AS],
}
# ------------------------------------------------------------------------------
# O'LIK WIDGETLAR (hech qanday usage yo'q, lekin repo'da git commit bo'lmagani
# uchun O'CHIRILMAYDI — faqat lokalizatsiya qilinadi va P2 sifatida hisobotga
# yoziladi): emergency_banner.dart, legal_basis_card.dart,
# risk_assessment_card.dart, actionable_steps_card.dart
# ------------------------------------------------------------------------------
SPEC[W + 'emergency_banner.dart'] = {
    'imports': [L10N],
    'l10nAnchor': ISDARK,
    'raw': [
        ("""content: Text("Qo'ng'iroq qilib bo'lmadi: $phone"),""",
         'content: Text(context.l10n.emergencyCallFailed(phone)),'),
        ('AppStrings.emergencyAlertTitle,', 'l10n.aiEmergencyAlertTitle,'),
        ('"${AppStrings.callHotline} (${protocol.emergencyHotline})",',
         '"${l10n.actionCallHotline} (${protocol.emergencyHotline})",'),
    ],
    'pairs': [
        ('Xavfli holatlar (Red Flags):', 'l10n.emergencyRedFlagsTitle'),
        ('Konstitutsiyaviy huquqlaringiz:',
         'l10n.emergencyConstitutionalRightsTitle'),
        ('Zudlik bilan nima qilish kerak:', 'l10n.emergencyImmediateActionsTitle'),
    ],
    'dropLines': [DROP_AS],
}

SPEC[W + 'legal_basis_card.dart'] = {
    'imports': [L10N],
    'l10nAnchor': ISDARK,
    'raw': [
        ("""const SnackBar(content: Text("Lex.uz havolasini ochib bo'lmadi")),""",
         'SnackBar(content: Text(context.l10n.aiLexUzOpenFailed)),'),
        ('AppStrings.legalBasisTitle,', 'l10n.aiLegalBasisTitle,'),
        ('AppStrings.openLexUz,', 'l10n.actionOpenLexUz,'),
    ],
    'pairs': [
        ('Rasmiy qonunchilik hujjatlari', 'l10n.aiOfficialDocsSubtitle'),
    ],
    'dropLines': [DROP_AS],
}

SPEC[W + 'risk_assessment_card.dart'] = {
    'imports': [L10N, AILBL],
    'l10nAnchor': ISDARK,
    'raw': [
        ('AppStrings.riskAssessmentTitle,', 'l10n.aiRiskTitle,'),
        ('assessment.level.displayName,', 'riskLevelLabel(l10n, assessment.level),'),
    ],
    'pairs': [
        ('Muhim cheklovlar va ogohlantirishlar:', 'l10n.aiLimitationsTitle'),
        ('Ushbu holatda mustaqil harakat qilish xavfli. Malakali advokat bilan '
         'maslahatlashish tavsiya etiladi.',
         'l10n.aiLawyerRecommendedWarning'),
    ],
    'dropLines': [DROP_AS],
}

SPEC[W + 'actionable_steps_card.dart'] = {
    'imports': [L10N],
    'l10nAnchor': ISDARK,
    'raw': [('AppStrings.actionableStepsTitle,', 'l10n.aiStepsTitle,')],
    'pairs': [],
    'dropLines': [DROP_AS],
}

# ---------------------------------------------- batch 3 qoldig'i: home_page.dart
SPEC['lib/features/home/presentation/pages/home_page.dart'] = {
    'imports': [L10N],
    'raw': [('child: const Text(AppStrings.retry),',
             'child: Text(l10n.actionRetry),')],
    'pairs': [],
    'dropLines': [DROP_AS],
}


def main() -> None:
    only = sys.argv[1:]
    total, failed, done = 0, [], []
    for path, spec in SPEC.items():
        if only and not any(k in path for k in only):
            continue
        try:
            n = apply_file(path, spec)
        except SystemExit as exc:
            print(f'FAIL {path}\n     {exc}')
            failed.append(path)
            continue
        total += n
        done.append(path)
        print(f'OK   {path}  (pairs={n})')
    print(f'\nTOTAL pairs replaced: {total}  |  files OK: {len(done)}')
    if failed:
        print('FAILED FILES:')
        for f in failed:
            print('  ' + f)
        raise SystemExit(1)


if __name__ == '__main__':
    main()

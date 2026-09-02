import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_assets.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/legal_ai_labels.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/shimmer_loading.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_remote_datasource.dart';
import 'package:lexhub/features/document_builder/domain/ai_document_routing.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';
import 'package:lexhub/features/document_builder/presentation/pages/document_generator_page.dart';
import 'package:lexhub/features/document_builder/presentation/pages/document_templates_page.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/presentation/bloc/legal_assistant_bloc.dart';
import 'package:lexhub/features/legal_assistant/presentation/bloc/legal_assistant_event.dart';
import 'package:lexhub/features/legal_assistant/presentation/bloc/legal_assistant_state.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/action_steps_timeline.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/ai_clarification_card.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/emergency_banner_widget.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/lawyer_escalation_card.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/legal_basis_accordion.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/relatable_summary_card.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/risk_matrix_gauge.dart';
import 'package:lexhub/features/saved_cases/presentation/pages/saved_cases_page.dart';

class LegalAssistantPage extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;

  const LegalAssistantPage({
    super.key,
    this.initialQuery,
    this.initialCategory,
  });

  @override
  State<LegalAssistantPage> createState() => _LegalAssistantPageState();
}

class _LegalAssistantPageState extends State<LegalAssistantPage> {
  late final TextEditingController _queryController;
  String? _selectedCategory;

  final List<Map<String, String>> _quickPromptChips = [
    {
      'label': "Ishdan nohaq bo'shatish",
      'query': "Ish beruvchi meni asossiz ravishda o'z xohishim bilan ariza yozishga majburlamoqda va ishdan bo'shatmoqchi. Qanday huquqlarim bor?",
    },
    {
      'label': "Iste'molchi huquqi (tovarni qaytarish)",
      'query': "Do'kondan kiyim sotib olgandim, lekin o'lchami to'g'ri kelmadi. 10 kun ichida qaytarib pulimni olsam bo'ladimi?",
    },
    {
      'label': "Aliment undirish",
      'query': "Farzandlarim uchun aliment undirmoqchiman. Ota rasman ishlamaydi, aliment qanday hisoblanadi va sudga qanday ariza beriladi?",
    },
    {
      'label': "Yo'l harakati jarimasi",
      'query': "Radar orqali noo'rin jarima qarori keldi. Ushbu ma'muriy qaror ustidan 10 kun ichida qanday shikoyat qilsam bo'ladi?",
    },
    {
      'label': "Qarz va tilxat",
      'query': "Tanishimga qarz bergan edim, tilxat yozib bergan. Pulni qaytarmayapti, sud orqali undirish tartibi qanday?",
    },
  ];

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery ?? '');
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  /// P0: `context` ATAYLAB parametr sifatida olinadi.
  ///
  /// Sabab — real qurilmada olingan crash: `Provider<LegalAssistantBloc>`
  /// `not found for LegalAssistantPage`. `BlocProvider` shu widget'ning O'Z
  /// `build()`ida (pastda) yaratiladi, ya'ni `State.context` provider'dan
  /// YUQORIDA turadi va uni ko'ra olmaydi. Ilgari bu metod `State.context`ni
  /// ishlatgani uchun har bir "tez vaziyat" chip'i bosilganda exception
  /// tashlanardi. `_submitQuery` esa allaqachon `BlocConsumer` builder
  /// context'ini qabul qiladi — endi ikkisi bir xil naqshda.
  void _onChipSelected(BuildContext context, Map<String, String> chip) {
    setState(() {
      _selectedCategory = chip['label'];
      _queryController.text = chip['query']!;
    });
    context
        .read<LegalAssistantBloc>()
        .add(CheckEmergencyTextEvent(chip['query']!));
  }

  void _submitQuery(BuildContext context) {
    final text = _queryController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.aiQueryEmptyError),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<LegalAssistantBloc>().add(
          SubmitLegalQueryEvent(
            queryText: text,
            category: _selectedCategory,
          ),
        );
  }

  void _copyAllAdvice(BuildContext context, LegalResponse response) {
    // HALOLLIK: `legalBasis` bo'sh bo'lsa ilgari "3. QONUNIY ASOSLAR" sarlavhasi
    // ostida BO'SH satr qolardi. Nusxalangan matn sudga yoki murojaatga
    // qo'yilishi mumkin, bo'sh sarlavha esa ikki xil o'qiladi: "asos yo'q"
    // yoki "asos bor, nusxalanmagan". Shuning uchun sabab AYNIQ yoziladi.
    // Yangi hardcoded literal qo'shilmaydi — mavjud ARB kaliti ishlatiladi.
    final legalBasisBlock = response.legalBasis.isEmpty
        ? context.l10n.aiLegalBasisNoneTitle
        : response.legalBasis
            .map((a) =>
                "• ${a.lawName}, ${a.articleNumber}: ${a.articleTitle}\n  ${a.lexUrl}")
            .join("\n");

    final text = """
HUQUQIY TAHLIL — LEXHUB PLATFORMASI

1. ODDIY TUSHUNTIRISH (XULOSA):
${response.relatableSummary}

2. QADAMMA-QADAM HARAKATLAR:
${response.actionableSteps.map((s) => "• $s").join("\n")}

3. QONUNIY ASOSLAR (LEX.UZ):
$legalBasisBlock

4. RISK VA MUDDATLAR:
${response.riskAssessment.summary}
""";
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.aiFullAnalysisCopied)),
    );
  }

  /// AI javobidan hujjat loyihasiga o'tish.
  ///
  /// ── TUZATILGAN IKKI NUQSON (auditda topilgan) ──
  ///
  /// 1. CRASH YO'LI: ilgari birinchi qator `DocumentTemplate selected =
  ///    templates.first` edi. `getTemplates()` bo'sh ro'yxat qaytarsa
  ///    (baza bo'sh, filtr, xato) bu `StateError` tashlaydi; `await` esa
  ///    `try` ichida bo'lmagani uchun exception `Future` ichida yo'qoladi —
  ///    tugma bosiladi, HECH NARSA bo'lmaydi, foydalanuvchi sababini
  ///    bilmaydi (§20: "silent fallback yo'q").
  ///
  /// 2. NOTO'G'RI HUJJAT XAVFI: kalit so'z topilmaganda `else` shoxi
  ///    MAJBURAN `template_consumer_refund` ni ochib, uning uch maydonini
  ///    javob matni bilan TO'LDIRARDI. Ya'ni soliq yoki migratsiya bo'yicha
  ///    QAMROVDAN TASHQARI javob olgan foydalanuvchi ham "iste'molchi
  ///    pulini qaytarish talabi" loyihasini olardi. Bu quvurning qolgan
  ///    qismidagi fail-closed tartibga QARAMA-QARSHI: grounding hech qanday
  ///    modda bermaganda `legalBasis` bo'sh qoladi, lekin hujjat
  ///    "tayyor bo'lib" chiqardi.
  ///    Endi: moslik topilmasa — shablonlar RO'YXATI ochiladi va sabab
  ///    aytiladi. Imkoniyat olib tashlanmadi, TANLOV foydalanuvchiga
  ///    qaytarildi.
  ///
  /// O'ZGARMAGAN: uchta mos kelgan shox (`mehnat`, `jarima`, `qarz`) va
  /// ularning `initialValues` to'ldirmasi — piksel va oqim AYNI.
  ///
  /// ── UCHINCHI NUQSON (2026-08-30 audit): KATALOG UCHTA EDI ──
  ///
  /// Bu metod `DocumentTemplatesDataSource` — faqat AI yo'liga xos, UCHINCHI
  /// qattiq yozilgan katalogni o'qirdi. Uning tarkibi ko'rib chiqiladigan
  /// katalog (baza seed'i + bundle) bilan MOS EMAS edi:
  ///
  ///   * `template_debt_pretenziya` faqat SHU katalogda bor edi — ya'ni AI
  ///     ochgan hujjatni foydalanuvchi katalogdan qayta topa olmasdi va
  ///     `user_documents.template_id` -> `document_templates(id)` FK'si uchun
  ///     ota qatori yo'q edi (saqlashda `23503`, xato esa release'da
  ///     KO'RINMAYDI — `document_templates_remote_datasource.dart`);
  ///   * `template_labor_complaint` maydon nomlari HAR XIL edi
  ///     (`violation_details` vs `violation_reason`), ya'ni quyidagi
  ///     to'ldirma mehnat shablonida HECH QAYERGA tushmasdi.
  ///
  /// Endi manba BITTA (`DocumentTemplatesRemoteDataSource` — baza, bundle
  /// zaxirasi bilan; ko'rib chiqish sahifasi ham AYNI shu manbani o'qiydi)
  /// va yo'naltirish jadvallari `AiDocumentRouting` da, testda katalogga
  /// solishtiriladi.
  Future<void> _openRelatedDocumentBuilder(
      BuildContext context, LegalResponse response) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final wantedId = AiDocumentRouting.templateIdFor(
      "${response.relatableSummary} ${response.actionableSteps.join(' ')}",
    );

    if (wantedId == null) {
      // Moslik yo'q: TANLOV foydalanuvchiga qaytariladi (yuqoridagi 2-nuqson).
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.aiDocumentPickTemplate)),
      );
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const DocumentTemplatesPage(),
        ),
      );
      return;
    }

    final DocumentTemplate template;
    try {
      template = await sl<DocumentTemplatesRemoteDataSource>()
          .getTemplateById(wantedId);
    } catch (_) {
      // Sabab YUTILMAYDI: foydalanuvchi nima uchun ochilmaganini biladi.
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.aiDocumentLoadFailed)),
        );
      }
      return;
    }
    if (!context.mounted) return;

    // TO'LDIRMA: maydon id'si shablonning O'ZIDA borligi TEKSHIRILADI.
    // Bazadagi qator bundle'dan farq qilsa (masalan maydon nomi
    // o'zgartirilsa) to'ldirma shunchaki BO'SH qoladi — mavjud bo'lmagan
    // kalitga yozib, jim yo'qotish qilinmaydi.
    final summaryField = AiDocumentRouting.summaryFieldFor(template.id);
    final hasField =
        summaryField != null && template.fields.any((f) => f.id == summaryField);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentGeneratorPage(
          template: template,
          initialValues: hasField
              ? {summaryField: response.relatableSummary}
              : const <String, String>{},
        ),
      ),
    );
  }

  List<String> _getClarificationQuestions(String query) {
    final lower = query.toLowerCase();
    if (lower.contains("ishdan") || lower.contains("mehnat")) {
      return const [
        "Ish beruvchi yozma buyruq (prikaz) nusxasini berdimi?",
        "Kasaba uyushmasi (profsoyuz) roziligi olinganmi?",
        "Ogohlantirish xati berilganiga necha kun bo'ldi?",
      ];
    } else if (lower.contains("jarima") || lower.contains("radar")) {
      return const [
        "Qaror nusxasi qaysi sanada sizga topshirildi?",
        "Radar o'rnatilgan hududda 70 yoki 60 belgilari to'g'ri joylashtirilganmidi?",
      ];
    } else if (lower.contains("qarz")) {
      return const [
        "Qarz berilganligi haqida qo'lda yozilgan tilxat bormi?",
        "Guvohlar yoki bank orqali pul o'tkazma cheklari mavjudmi?",
      ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => sl<LegalAssistantBloc>(),
      child: Scaffold(
        appBar: AppBar(
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.maybePop(context),
                )
              : null,
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.asset(
                    AppAssets.appLogo,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.balance_rounded,
                      color: AppColors.accent,
                      size: AppIconSize.sm,
                    ),
                  ),
                ),
              ),
              const Gap(AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    l10n.aiAnalystSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      // O'LCHANGAN TUZATISH: 10 px → 11 px (loyihadagi poli) va
                      // qorong'i mavzuda rang `indigo` (#6366F1) edi —
                      // `surfaceDark` AppBar foni ustida 4.00:1, ya'ni MATN
                      // uchun AA (4.5:1) dan past. `indigoOnTintDark`
                      // (#A5B4FC) ayni fonda 8.96:1.
                      fontSize: 11,
                      color: isDark
                          ? AppColors.indigoOnTintDark
                          : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.folder_special_rounded),
              tooltip: l10n.savedCasesTitle,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavedCasesPage()),
                );
              },
            ),
          ],
        ),
        body: BlocConsumer<LegalAssistantBloc, LegalAssistantState>(
          listener: (context, state) {
            if (state is LegalAssistantError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorStateText(context.l10n, state.message, state.code)),
                  // SnackBar matni oq: `emergency` (#EF4444) fonda 3.76:1
                  // bo'lardi (AA = 4.5:1), `emergencyStrong` da 6.47:1.
                  backgroundColor: AppColors.emergencyStrong,
                ),
              );
            }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emergency Banner if live emergency is detected
                  if (state is LegalAssistantInitial && state.liveEmergencyWarning != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: EmergencyBannerWidget(protocol: state.liveEmergencyWarning!),
                    ),

                  // Prompt input container
                  ModernContainer(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // §6 HALOLLIK: uchqun (`auto_awesome`) EMAS. Bu
                            // ikonka SAVOL YOZISH maydonining tepasida, ya'ni
                            // javob manbasi HALI ANIQ EMAS holatida turadi:
                            // tizimga kirmagan foydalanuvchida server modeli
                            // umuman chaqirilmaydi va javob qurilmadagi
                            // tekshirilgan qonun bazasidan keladi. Uchqun esa
                            // shartsiz "AI" da'vosi bo'lar edi.
                            // Uchqun FAQAT `relatable_summary_card.dart` da,
                            // javob HAQIQATAN model'dan kelganda (`isLlm`)
                            // ko'rsatiladi — shu qoida bir joyda buzilgan edi.
                            //
                            // RANG: ilgari `indigo` (#6366F1) edi — qorong'i
                            // kartada 3.27:1, ya'ni WCAG 1.4.11 grafik
                            // minimumidan (3:1) faqat 0.27 yuqori. Endi
                            // `AppTone.accentIndigo.on()`: 4.67:1 / 5.91:1.
                            Icon(
                              Icons.gavel_rounded,
                              color: AppTone.accentIndigo.on(isDark),
                              size: AppIconSize.sm,
                            ),
                            const Gap(AppSpacing.sm),
                            Text(
                              l10n.aiWriteSituationTitle,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Gap(AppSpacing.md),
                        TextField(
                          controller: _queryController,
                          maxLines: 4,
                          onChanged: (val) {
                            context
                                .read<LegalAssistantBloc>()
                                .add(CheckEmergencyTextEvent(val));
                          },
                          decoration: InputDecoration(
                            hintText: l10n.aiQueryHint,
                            hintStyle: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              height: 1.4,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                          ),
                        ),
                        const Gap(AppSpacing.md + 2),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: state is LegalAssistantLoading
                                ? null
                                : () => _submitQuery(context),
                            icon: state is LegalAssistantLoading
                                ? const SizedBox(
                                    width: AppIconSize.xs + 2,
                                    height: AppIconSize.xs + 2,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send_rounded, size: AppIconSize.sm),
                            label: Text(
                              state is LegalAssistantLoading
                                  ? l10n.aiAnalyzingLexUz
                                  : l10n.aiGetAdviceButton,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Gap(AppSpacing.lg),

                  // Quick prompt chips
                  if (state is! LegalAssistantSuccess && state is! LegalAssistantLoading) ...[
                    Text(
                      l10n.aiCommonSituations,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _quickPromptChips.map((chip) {
                        return ActionChip(
                          // 14 px ikonka ham grafik obyekt: `indigo` chip foni
                          // ustida 3.27:1 edi, endi 4.67:1 / 5.91:1.
                          avatar: Icon(
                            Icons.bolt_rounded,
                            size: AppIconSize.xs,
                            color: AppTone.accentIndigo.on(isDark),
                          ),
                          label: Text(legalAiChipLabel(l10n, chip['label']!),
                              // `RawChip` yorliqni o'lchangan kenglikka TENG
                              // `maxWidth` bilan qayta layout qiladi va
                              // `TextOverflow.fade` ni majburlaydi — oxirgi
                              // glif so'nadi. Yorliqlar `_quickPromptChips`
                              // qat'iy ro'yxatidan.
                              overflow: TextOverflow.visible,
                              style: const TextStyle(fontSize: 11)),
                          onPressed: () => _onChipSelected(context, chip),
                        );
                      }).toList(),
                    ),
                    const Gap(AppSpacing.xxl),
                  ],

                  // Shimmer Loading State
                  if (state is LegalAssistantLoading) const LegalAnalysisShimmer(),

                  // Success State: 4-Layer Legal Response + Clarification Questions
                  if (state is LegalAssistantSuccess) ...[
                    if (state.response.emergencyProtocol != null) ...[
                      EmergencyBannerWidget(protocol: state.response.emergencyProtocol!),
                      const Gap(AppSpacing.lg),
                    ],

                    // Layer 1: Relatable Summary
                    //
                    // HALOLLIK BADGE'i — javob QAYERDAN kelgani — endi
                    // kartaning ICHIDA (`relatable_summary_card.dart`).
                    //
                    // NIMA UCHUN KO'CHIRILDI: ilgari badge shu sahifada
                    // alohida `Row` bo'lgan, shuning uchun AYNI xulosa matnini
                    // ko'rsatadigan `saved_cases_page`, `recent_cases_feed` va
                    // `faq_questions_page` manbani UMUMAN oshkor qilmasdi.
                    // O'LCHANGAN (2026-08-26, production): proxy `ai_timeout`
                    // qaytarganda javob HAR SAFAR deterministik bo'ladi, ya'ni
                    // bu teshik nazariy emas edi.
                    RelatableSummaryCard(
                      summary: state.response.relatableSummary,
                      source: state.response.source,
                    ),
                    const Gap(AppSpacing.lg),

                    // Multi-turn Clarification Questions
                    Builder(
                      builder: (_) {
                        final clarifications = _getClarificationQuestions(_queryController.text);
                        return AiClarificationCard(
                          questions: clarifications,
                          onQuestionTapped: (q) {
                            _queryController.text = "${_queryController.text}\nQo'shimcha: $q javobi - ";
                          },
                        );
                      },
                    ),
                    const Gap(AppSpacing.lg),

                    // Layer 2: Actionable Steps Timeline
                    ActionStepsTimeline(steps: state.response.actionableSteps),
                    const Gap(AppSpacing.lg),

                    // Layer 3: Credible Grounding (Lex.uz Articles)
                    LegalBasisAccordion(articles: state.response.legalBasis),
                    const Gap(AppSpacing.lg),

                    // Layer 4: Risk Matrix Gauge & Deadlines
                    RiskMatrixGauge(assessment: state.response.riskAssessment),

                    // Layer 5: ADVOKATGA ESKALATSIYA — quvurning oxirgi va
                    // eng qimmat bo'g'ini.
                    //
                    // AUDITDA O'LCHANGAN UZILISH: `requiresLawyer` FAQAT
                    // `risk_matrix_gauge.dart:296` da matn bo'lib chiqardi,
                    // hech qanday `onPressed` YO'Q edi — ya'ni "sizga advokat
                    // kerak" xulosasi boshi berk ko'cha edi. Qamrovdan
                    // tashqari HAR BIR javobda `_applyCoverageHonesty`
                    // `requiresLawyer: true` beradi, demak bu eng ko'p
                    // uchraydigan holat ham edi.
                    //
                    // SHART ATAYLAB `requiresLawyer`: har bir javobga advokat
                    // tugmasi qo'yilsa signal kuchini yo'qotadi. Yo'nalish
                    // so'rov matnidan `LegalCoverage.classify()` bilan
                    // aniqlanadi — quvur ishlatgan AYNI funksiya.
                    if (state.response.riskAssessment.requiresLawyer) ...[
                      const Gap(AppSpacing.lg),
                      LawyerEscalationCard(queryText: _queryController.text),
                    ],
                    const Gap(AppSpacing.xl),

                    // Legal Disclaimer Banner
                    //
                    // O'LCHANGAN TUZATISH: fon `amberLight` / `amberDarkBg`,
                    // matn va ikonka `amberDark` (#D97706) edi — yorug'da
                    // 2.86:1, ya'ni 11 px matn uchun AA (4.5:1) dan
                    // ANIQ past. Endi uchala rang ham bir manbadan —
                    // `AppTone.warning`: `on()` 5.86:1 / 7.07:1.
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppTone.warning.bg(isDark),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppTone.warning.border(isDark)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: AppIconSize.sm,
                            color: AppTone.warning.on(isDark),
                          ),
                          const Gap(AppSpacing.sm),
                          Expanded(
                            child: Text(
                              l10n.legalDisclaimer,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: AppTone.warning.on(isDark),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Gap(AppSpacing.lg),

                    // Bottom Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _copyAllAdvice(context, state.response),
                            icon: const Icon(Icons.copy_rounded, size: AppIconSize.xs + 2),
                            label: Text(l10n.actionCopyAnalysis),
                          ),
                        ),
                        const Gap(AppSpacing.sm + 2),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openRelatedDocumentBuilder(context, state.response),
                            icon: const Icon(Icons.description_rounded, size: AppIconSize.xs + 2),
                            label: Text(l10n.aiBuildDocumentAction),
                          ),
                        ),
                      ],
                    ),

                    // Pastdagi navigatsiya paneli ostida qolmasligi uchun
                    // 24 → `bottomSafe` (32).
                    const Gap(AppSpacing.bottomSafe),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

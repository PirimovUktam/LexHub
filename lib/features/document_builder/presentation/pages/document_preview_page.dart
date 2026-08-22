import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';
import 'package:lexhub/features/document_builder/domain/entities/saved_user_document.dart';
import 'package:lexhub/features/document_builder/domain/repositories/document_builder_repository.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';
import 'package:lexhub/features/legal_assistant/domain/usecases/saved_cases_usecases.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class DocumentPreviewPage extends StatefulWidget {
  final DocumentTemplate template;
  final String generatedText;
  final Map<String, String> formValues;

  const DocumentPreviewPage({
    super.key,
    required this.template,
    required this.generatedText,
    required this.formValues,
  });

  @override
  State<DocumentPreviewPage> createState() => _DocumentPreviewPageState();
}

class _DocumentPreviewPageState extends State<DocumentPreviewPage> {
  bool _isSaved = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.generatedText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.documentCopiedSnack),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openLexUz() async {
    final url = widget.template.sourceUrl;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _saveDocument() async {
    final docId = const Uuid().v4();

    // 1. Save to Offline Cases (Hive)
    final saveUseCase = sl<SaveCaseUseCase>();
    final response = LegalResponse(
      id: docId,
      queryId: widget.template.id,
      relatableSummary: "Rasmiy Hujjat: ${widget.template.title}",
      actionableSteps: const [
        "Ushbu hujjatni 2 nusxada chop eting.",
        "Tegishli tashkilot yoki sud qabulxonasiga topshirib, 2-nusxaga kirish raqami (shtamp) qo'ydiring.",
        "Qonunda belgilangan muddatda rasmiy javobni kuting.",
      ],
      legalBasis: [
        LawArticle(
          lawName: widget.template.category,
          articleNumber: "Asosiy norma",
          articleTitle: widget.template.title,
          articleText: widget.generatedText,
          lexUrl: widget.template.sourceUrl ?? "https://lex.uz",
        ),
      ],
      riskAssessment: const RiskAssessment(
        level: RiskLevel.low,
        summary: "Hujjat rasmiy talablarga to'liq muvofiq tuzilgan.",
      ),
      isSaved: true,
      createdAt: DateTime.now(),
    );
    await saveUseCase(response);

    // 2. Save to User Documents Repository (Supabase Sync)
    final userDoc = SavedUserDocument(
      id: docId,
      userId: '',
      templateId: widget.template.id,
      title: widget.template.title,
      category: widget.template.category,
      formValues: widget.formValues,
      generatedText: widget.generatedText,
      legalBasis: widget.template.legalBasisSummary,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final repo = sl<DocumentBuilderRepository>();
    await repo.saveUserDocument(userDoc);

    setState(() {
      _isSaved = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.documentSavedSnack),
          backgroundColor: AppColors.emeraldDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.documentPreviewTitle,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              color: _isSaved ? AppColors.amberDark : null,
            ),
            tooltip: l10n.documentSaveTooltip,
            onPressed: _isSaved ? null : _saveDocument,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: l10n.actionCopy,
            onPressed: _copyToClipboard,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Freshness & Grounding Badge
            ModernContainer(
              padding: const EdgeInsets.all(14),
              backgroundColor: isDark ? AppColors.emerald.withValues(alpha: 0.15) : AppColors.emeraldLight,
              borderColor: isDark ? AppColors.emerald.withValues(alpha: 0.3) : AppColors.emerald.withValues(alpha: 0.4),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: AppColors.emeraldDark, size: 20),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.documentLegalBasisWith(widget.template.legalBasisSummary),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          l10n.documentReadyToPrint,
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  if (widget.template.sourceUrl != null)
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.emeraldDark),
                      tooltip: l10n.actionViewOnLexUz,
                      onPressed: _openLexUz,
                    ),
                ],
              ),
            ),

            const Gap(16),

            // Official Document Paper Sheet
            ModernContainer(
              padding: const EdgeInsets.all(20),
              backgroundColor: isDark ? AppColors.cardDark : Colors.white,
              borderColor: isDark ? AppColors.borderDark : AppColors.borderLight,
              borderWidth: 1.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    widget.generatedText,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 13.5,
                      height: 1.65,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),

            const Gap(20),

            // Action Toolbar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(l10n.actionCopy),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaved ? null : _saveDocument,
                    icon: Icon(
                      _isSaved ? Icons.check_circle_rounded : Icons.save_alt_rounded,
                      size: 18,
                    ),
                    label: Text(_isSaved ? l10n.actionSaved : l10n.actionSave),
                  ),
                ),
              ],
            ),

            const Gap(32),
          ],
        ),
      ),
    );
  }
}

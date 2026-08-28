import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_form_field.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_bloc.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_event.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_state.dart';
import 'package:lexhub/features/document_builder/presentation/pages/document_preview_page.dart';

class DocumentGeneratorPage extends StatelessWidget {
  final DocumentTemplate template;
  final Map<String, String>? initialValues;

  const DocumentGeneratorPage({
    super.key,
    required this.template,
    this.initialValues,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => sl<DocumentBuilderBloc>()
        ..add(SelectTemplateForGenerationEvent(
          template: template,
          initialValues: initialValues,
        )),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            template.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: BlocConsumer<DocumentBuilderBloc, DocumentBuilderState>(
          listener: (context, state) {
            if (state is DocumentGeneratedSuccess) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentPreviewPage(
                    template: state.template,
                    generatedText: state.generatedText,
                    formValues: state.formValues,
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is DocumentFormEditing) {
              final isDark = theme.brightness == Brightness.dark;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Legal Reference Pill
                    ModernContainer(
                      padding: const EdgeInsets.all(14),
                      backgroundColor: isDark ? AppColors.lexBlueDarkBg : AppColors.lexBlueLight,
                      borderColor: isDark ? AppColors.lexBlueDarkBorder : AppColors.lexBlue.withValues(alpha: 0.3),
                      child: Row(
                        children: [
                          // O'LCHANGAN: ikonka IKKI mavzuda ham XOM
                          // `lexBlue` edi — `lexBlueLight` ustida 3.57:1,
                          // `lexBlueDarkBg` ustida 3.85:1 (1.4.11 chegarasi).
                          // Ton: 6.59 / 7.35.
                          Icon(Icons.verified_rounded,
                              color: AppTone.info.on(isDark), size: 20),
                          const Gap(10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.documentLegalBasisLabel,
                                  // O'LCHANGAN DEFEKT: qorong'ida `lexBlue`
                                  // `lexBlueDarkBg` ustida 3.85:1 — 11 px
                                  // qalin matn uchun AA (4.5:1) dan past.
                                  // Ton: 6.59 / 7.35 (fon O'ZGARMAYDI).
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: AppTone.info.on(isDark),
                                  ),
                                ),
                                Text(
                                  template.legalBasisSummary,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Gap(18),

                    Text(
                      l10n.documentFillFieldsTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const Gap(12),

                    ...template.fields.map((field) {
                      final val = state.formValues[field.id] ?? '';
                      final error = state.validationErrors[field.id];
                      final isMultiline = field.fieldType == DocumentFieldType.multiline;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  field.label,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (field.isRequired)
                                  const Text(
                                    " *",
                                    style: TextStyle(
                                      color: AppColors.emergency,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            const Gap(6),
                            TextFormField(
                              initialValue: val,
                              maxLines: isMultiline ? 4 : 1,
                              keyboardType: field.fieldType == DocumentFieldType.number
                                  ? TextInputType.number
                                  : (isMultiline
                                      ? TextInputType.multiline
                                      : TextInputType.text),
                              onChanged: (newVal) {
                                context.read<DocumentBuilderBloc>().add(
                                      UpdateFormFieldEvent(
                                        fieldId: field.id,
                                        value: newVal,
                                      ),
                                    );
                              },
                              decoration: InputDecoration(
                                hintText: field.placeholder,
                                errorText: error,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const Gap(16),

                    ElevatedButton.icon(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        context.read<DocumentBuilderBloc>().add(
                              const GenerateFinalDocumentEvent(),
                            );
                      },
                      icon: const Icon(Icons.description_rounded, size: 20),
                      label: Text(l10n.documentGenerateAction),
                    ),

                    const Gap(32),
                  ],
                ),
              );
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}

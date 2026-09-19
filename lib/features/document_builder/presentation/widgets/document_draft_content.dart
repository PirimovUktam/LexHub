import 'package:flutter/material.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';

/// Generated text is a user's draft, never a law quotation or a risk verdict.
class DocumentDraftContent extends StatelessWidget {
  const DocumentDraftContent({super.key, required this.response});

  final LegalResponse response;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.documentDraftLabel,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(context.l10n.documentDraftDisclaimer),
          const SizedBox(height: 16),
          SelectableText(response.documentText ?? ''),
        ],
      );
}

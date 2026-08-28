import 'package:flutter/material.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/auth/presentation/pages/profile_tab_page.dart';
import 'package:lexhub/features/consultations/presentation/pages/my_consultations_page.dart';
import 'package:lexhub/features/document_builder/presentation/pages/document_templates_page.dart';
import 'package:lexhub/features/saved_cases/presentation/pages/saved_cases_page.dart';

class DocumentsAndSavedHubPage extends StatelessWidget {
  const DocumentsAndSavedHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.cabinetTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          bottom: TabBar(
            // O'LCHANGAN DEFEKT: TANLANGAN tab yorlig'i qorong'ida XOM
            // `indigo` edi — `appBarTheme` foni (`surfaceDark`) ustida
            // 4.00:1, ya'ni 14 px yorliq matni uchun AA (4.5:1) dan PAST:
            // "qaysi tab ochiq" signali chegaradan past kontrastda edi.
            // Ton: 8.96:1. Indikator chizig'i ham ayni tonga ko'chdi —
            // yorliq bilan bitta rangda bo'lishi kerak (ilgari 4.00:1,
            // 1.4.11 dan o'tardi, lekin yorliqdan boshqa rangda edi).
            // Yorug' tomon `primary` bilan 17.85:1 — o'zgarmaydi.
            indicatorColor:
                isDark ? AppTone.accentIndigo.on(true) : AppColors.primary,
            labelColor:
                isDark ? AppTone.accentIndigo.on(true) : AppColors.primary,
            unselectedLabelColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                icon: const Icon(Icons.person_outline_rounded),
                text: l10n.cabinetTabProfile,
              ),
              Tab(
                icon: const Icon(Icons.event_available_rounded),
                text: l10n.cabinetTabConsultations,
              ),
              Tab(
                icon: const Icon(Icons.description_outlined),
                text: l10n.cabinetTabBuilder,
              ),
              Tab(
                icon: const Icon(Icons.bookmark_outline_rounded),
                text: l10n.cabinetTabOfflineCases,
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ProfileTabPage(),
            MyConsultationsPage(),
            DocumentTemplatesPage(),
            SavedCasesPage(),
          ],
        ),
      ),
    );
  }
}


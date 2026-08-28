import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/expert_labels.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_bloc.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_event.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_state.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/apply_expert_dialog.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/expert_card_widget.dart';

class LegalExpertsPage extends StatelessWidget {
  const LegalExpertsPage({super.key});

  // XOM FILTR QIYMATLARI (§16): bu ro'yxat `.ilike('specialization', …)` /
  // `.ilike('city', …)` ga QIYMAT sifatida ketadi, shuning uchun tarjima
  // QILINMAYDI. Ekranda ko'rinadigan matn `expertSpecializationChipLabel()` /
  // `expertCityLabel()` orqali beriladi.
  static const List<String> _specializations = [
    "Barchasi",
    "Mehnat",
    "Oila",
    "Jinoyat",
    "Yo'l harakati",
    "Iste'molchi",
    "Soliq",
    "Biznes",
  ];

  static const List<String> _cities = [
    "Barcha viloyatlar",
    "Toshkent sh.",
    "Samarqand sh.",
    "Farg'ona sh.",
    "Buxoro sh.",
    "Andijon sh.",
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) =>
          sl<LegalExpertsBloc>()..add(const LoadLegalExpertsEvent()),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                l10n.expertsTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: l10n.expertsApplyTooltip,
                  icon: const Icon(Icons.app_registration_rounded),
                  onPressed: () {
                    final bloc = context.read<LegalExpertsBloc>();
                    showDialog(
                      context: context,
                      builder: (_) => BlocProvider.value(
                        value: bloc,
                        child: const ApplyExpertDialog(),
                      ),
                    );
                  },
                ),
              ],
            ),
        body: BlocBuilder<LegalExpertsBloc, LegalExpertsState>(
          builder: (context, state) {
            final bloc = context.read<LegalExpertsBloc>();
            final isDark = theme.brightness == Brightness.dark;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  ModernContainer(
                    // Tint fon/chegara endi markazdagi `AppTone` dan: qulf
                    // testi alfa 0.00–0.20 konvertini tekshiradi, ya'ni
                    // qo'lda yozilgan 0.12/0.06/0.3/0.2 qiymatlar bilan
                    // farqli o'laroq bu juftlik o'lchangan.
                    backgroundColor: AppTone.accentIndigo.bg(isDark),
                    borderColor: AppTone.accentIndigo.border(isDark),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm + 2),
                          decoration: BoxDecoration(
                            // O'LCHANGAN: to'ldirilgan yuza + OQ 24 px
                            // ikonka. `indigo` bilan 4.47:1 — GRAFIK uchun
                            // (1.4.11 → 3:1) yetarli, shuning uchun brend
                            // rangi SAQLANADI; yuza chegarasi karta tinti
                            // ustida 3.33:1 (qorong'i) / 15.08:1 (yorug').
                            color: isDark ? AppColors.indigo : AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: Colors.white,
                            size: AppIconSize.lg - 2,
                          ),
                        ),
                        const Gap(AppSpacing.md + 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.expertsHeaderTitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Gap(2),
                              Text(
                                l10n.expertsHeaderSubtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Gap(16),

                  // Search Bar
                  TextField(
                    onChanged: (val) {
                      bloc.add(SearchLegalExpertsEvent(val));
                    },
                    decoration: InputDecoration(
                      hintText: l10n.expertsSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      fillColor: theme.colorScheme.surface,
                    ),
                  ),

                  const Gap(14),

                  // Specialization Filter Chips
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _specializations.length,
                      separatorBuilder: (_, __) => const Gap(8),
                      itemBuilder: (context, index) {
                        final spec = _specializations[index];
                        final isSelected = (state is LegalExpertsLoaded &&
                                (state.selectedSpecialization == spec ||
                                    (state.selectedSpecialization == null &&
                                        spec == "Barchasi"))) ||
                            (state is! LegalExpertsLoaded && index == 0);

                        return ChoiceChip(
                          label: Text(
                            expertSpecializationChipLabel(l10n, spec),
                            // `RawChip` yorliqni o'lchangan kenglikka TENG
                            // `maxWidth` bilan qayta layout qiladi va
                            // `TextOverflow.fade` ni majburlaydi. Bu ekranda
                            // yorliqlar qisqa bo'lgani uchun nuqson hozircha
                            // KO'RINMAYDI, lekin ingliz tilida yoki uzunroq
                            // soha nomida ayni holat yuzaga keladi.
                            overflow: TextOverflow.visible,
                          ),
                          selected: isSelected,
                          // O'LCHANGAN: tanlangan fon `indigo` + OQ 12 px
                          // bold yorliq = 4.47:1 (12 px bold "yirik matn"
                          // EMAS) → AA'dan past. `indigoDark`: 6.29:1.
                          selectedColor: isDark ? AppColors.indigoDark : AppColors.primary,
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(
                            // Tanlangan chegara ham `indigoDark` edi va u
                            // `surfaceDark` ustida 2.80:1 — konturi
                            // ko'rinmasdi. `indigoOnTintDark`: 8.96:1.
                            color: isSelected
                                ? (isDark
                                    ? AppColors.indigoOnTintDark
                                    : AppColors.primary)
                                : (isDark ? AppColors.borderDark : AppColors.borderLight),
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            bloc.add(FilterSpecializationEvent(
                              spec == "Barchasi" ? null : spec,
                            ));
                          },
                        );
                      },
                    ),
                  ),

                  const Gap(12),

                  // City Filter Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.expertsRegionLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DropdownButton<String>(
                        value: state is LegalExpertsLoaded
                            ? (state.selectedCity ?? "Barcha viloyatlar")
                            : "Barcha viloyatlar",
                        underline: const SizedBox.shrink(),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: AppIconSize.sm),
                        style: TextStyle(
                          // O'LCHANGAN: `indigo` (#6366F1) qorong'i sahifa
                          // foni (#0A192F) ustida 3.94:1 — 13 px bold MATN
                          // uchun AA (4.5:1) dan past. `AppTone.accentIndigo`
                          // qorong'ida `indigoOnTintDark` (8.83:1), yorug'da
                          // `indigoDark` (6.01:1) beradi — yorug' qiymat
                          // `primary` (17.05:1) dan pastroq, lekin AA'dan
                          // yuqori va aksent rangi butun ilovada BIR XIL
                          // tondan olinadi.
                          color: AppTone.accentIndigo.on(isDark),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        dropdownColor: theme.colorScheme.surface,
                        items: _cities.map((c) {
                          return DropdownMenuItem<String>(
                            value: c,
                            child: Text(expertCityLabel(l10n, c)),
                          );
                        }).toList(),
                        onChanged: (newCity) {
                          bloc.add(FilterCityEvent(
                            newCity == "Barcha viloyatlar" ? null : newCity,
                          ));
                        },
                      ),
                    ],
                  ),

                  const Gap(12),

                  // Results List
                  if (state is LegalExpertsLoading) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ] else if (state is LegalExpertsError) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // O'LCHANGAN: `emergency` (#EF4444) yorug' fonda
                            // 3.60:1 — ton bo'yicha olinganda 6.18:1
                            // (yorug') / 9.27:1 (qorong'i).
                            Icon(
                              Icons.error_outline_rounded,
                              color: AppTone.danger.on(isDark),
                              size: AppIconSize.empty - 8,
                            ),
                            const Gap(AppSpacing.sm),
                            Text(errorStateText(context.l10n, state.message, state.code)),
                            const Gap(12),
                            ElevatedButton(
                              onPressed: () =>
                                  bloc.add(const LoadLegalExpertsEvent()),
                              child: Text(l10n.actionRetry),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (state is LegalExpertsLoaded) ...[
                    if (state.experts.isEmpty) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            l10n.expertsEmptyFiltered,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.experts.length,
                        separatorBuilder: (_, __) => const Gap(12),
                        itemBuilder: (context, index) {
                          final expert = state.experts[index];
                          return ExpertCardWidget(expert: expert);
                        },
                      ),
                    ],
                  ],

                  const Gap(32),
                ],
              ),
            );
          },
        ),
      );
    },
  ),
);
  }
}

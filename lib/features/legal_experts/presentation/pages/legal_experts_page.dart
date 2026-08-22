import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/expert_labels.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
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
                    backgroundColor: isDark
                        ? AppColors.indigo.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.06),
                    borderColor: isDark
                        ? AppColors.indigo.withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.2),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.indigo : AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const Gap(14),
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
                          ),
                          selected: isSelected,
                          selectedColor: isDark ? AppColors.indigo : AppColors.primary,
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(
                            color: isSelected
                                ? (isDark ? AppColors.indigo : AppColors.primary)
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
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                        style: TextStyle(
                          color: isDark ? AppColors.indigo : AppColors.primary,
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
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.emergency,
                              size: 40,
                            ),
                            const Gap(8),
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

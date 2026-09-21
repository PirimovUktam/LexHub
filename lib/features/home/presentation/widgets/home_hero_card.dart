import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/role_labels.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_state.dart';

/// SearchPage retains ownership of input, debounce, requests and results.
class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({super.key, required this.onSearchTap});
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 600;
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.topRight,
              child: ExcludeSemantics(
                child: Image.asset(
                  'assets/images/home_justice_art.png',
                  width: constraints.maxWidth * 0.48,
                  fit: BoxFit.cover,
                  alignment: Alignment.topRight,
                  opacity: AlwaysStoppedAnimation(wide ? 0.6 : 0.18),
                ),
              ),
            ),
          ),
          Padding(
            padding:
                EdgeInsets.all(wide ? AppSpacing.bottomSafe : AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GreetingRow(),
                const Gap(AppSpacing.lg),
                FractionallySizedBox(
                  widthFactor: wide ? 0.74 : 1,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: l10n.homeHeroTitleLead),
                      TextSpan(
                          text: l10n.homeHeroTitleAccent,
                          style: const TextStyle(
                              color: AppColors.indigoOnTintDark)),
                    ]),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: wide ? 36 : 28,
                      height: 1.25,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const Gap(AppSpacing.md),
                FractionallySizedBox(
                  widthFactor: wide ? 0.75 : 1,
                  child: Text(l10n.homeHeroDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondaryDark, height: 1.6)),
                ),
                const Gap(AppSpacing.xxl),
                Semantics(
                  button: true,
                  child: Material(
                    color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onSearchTap,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(children: [
                          Icon(Icons.search_rounded,
                              color: isDark ? Colors.white : AppColors.primary),
                          const Gap(AppSpacing.md),
                          Expanded(
                              child: Text(l10n.homeQueryHint,
                                  style: theme.textTheme.bodyMedium)),
                          const Gap(AppSpacing.sm),
                          Tooltip(
                            message: l10n.homeAiAnalyzeButton,
                            child: Container(
                              width: kMinInteractiveDimension,
                              height: kMinInteractiveDimension,
                              decoration: BoxDecoration(
                                color: AppColors.indigoDark,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                              ),
                              child: const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: AppIconSize.md),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      );
    });
  }
}

class _GreetingRow extends StatelessWidget {
  const _GreetingRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      final profile = state is Authenticated ? state.profile : null;
      final name = profile?.fullName.trim();
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            name != null && name.isNotEmpty
                ? '${l10n.homeGreeting}, $name'
                : l10n.homeGreeting,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondaryDark),
          ),
          if (profile != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                roleLabelFromDbValue(l10n, profile.role.toDbValue()),
                style:
                    theme.textTheme.labelSmall?.copyWith(color: Colors.white),
              ),
            ),
        ],
      );
    });
  }
}

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
      final stacked = constraints.maxWidth < 350 ||
          MediaQuery.textScalerOf(context).scale(16) > 22;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ColoredBox(
          color: AppColors.primaryDark,
          child: Stack(children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomRight,
                child: ExcludeSemantics(
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [Colors.transparent, Colors.white],
                      stops: [0, 0.28],
                    ).createShader(rect),
                    child: Image.asset(
                      'assets/images/home_justice_art.png',
                      width: constraints.maxWidth * (stacked ? 0.55 : 0.48),
                      fit: BoxFit.cover,
                      alignment: Alignment.bottomRight,
                      opacity: AlwaysStoppedAnimation(stacked ? 0.22 : 1),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _GreetingRow(),
                  const Gap(AppSpacing.md),
                  FractionallySizedBox(
                    widthFactor: stacked ? 1 : 0.62,
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
                        height: 1.16,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const Gap(AppSpacing.lg),
                  FractionallySizedBox(
                    widthFactor: stacked ? 1 : 0.61,
                    child: Text(
                      l10n.homeHeroDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryDark,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
        // The overlap occupies real layout space, including its hit area.
        Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryDark,
              isDark ? AppColors.backgroundDark : AppColors.backgroundLight
            ],
            stops: const [0.49, 0.5],
          )),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Semantics(
            button: true,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.indigo.withValues(alpha: 0.18),
                    blurRadius: AppSpacing.xxl,
                    offset: const Offset(0, AppSpacing.sm),
                  )
                ],
              ),
              child: Material(
                color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onSearchTap,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(children: [
                      const Gap(AppSpacing.sm),
                      Icon(Icons.search_rounded,
                          color: isDark ? Colors.white : AppColors.primary),
                      const Gap(AppSpacing.md),
                      Expanded(
                          child: Text(
                        l10n.homeQueryHint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      )),
                      const Gap(AppSpacing.sm),
                      Tooltip(
                        message: l10n.homeAiAnalyzeButton,
                        child: Container(
                          width: kMinInteractiveDimension,
                          height: kMinInteractiveDimension,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [
                              AppColors.indigoDark,
                              AppColors.indigo,
                            ]),
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: AppIconSize.lg),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}

/// Authentication, profile identity and read-only role are unchanged.
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

import 'package:flutter/material.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';

/// A scrollable form on phones, with a separate brand panel on desktop.
/// Authentication state and navigation stay in the calling page.
class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= AppLayout.twoColumns;
          final inset = wide ? AppSpacing.bottomSafe : AppSpacing.lg;
          return SingleChildScrollView(
            padding: EdgeInsets.all(inset),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - inset * 2)
                    .clamp(0, double.infinity),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (wide) ...[
                        const Expanded(child: _AuthBrandPanel()),
                        const SizedBox(width: AppSpacing.bottomSafe * 2),
                      ],
                      Expanded(
                        child: Align(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppLayout.formWidth,
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      );
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.bottomSafe),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.asset('assets/images/home_brand_mark.png',
                  width: 56, height: 56, excludeFromSemantics: true),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(l10n.appName,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: Colors.white)),
            ),
          ]),
          const SizedBox(height: AppSpacing.bottomSafe),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: l10n.homeHeroTitleLead),
              TextSpan(
                text: l10n.homeHeroTitleAccent,
                style: const TextStyle(color: AppColors.indigoOnTintDark),
              ),
            ]),
            style: theme.textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.homeHeroDescription,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: AppColors.textSecondaryDark)),
          const SizedBox(height: AppSpacing.xxl),
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.asset('assets/images/home_justice_art.png',
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(l10n.homeBrandTagline,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: AppColors.textSecondaryDark)),
        ],
      ),
    );
  }
}

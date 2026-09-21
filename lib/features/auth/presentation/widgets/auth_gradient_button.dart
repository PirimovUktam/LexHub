import 'package:flutter/material.dart';
import 'package:lexhub/core/theme/app_dimens.dart';

class AuthGradientButton extends StatelessWidget {
  const AuthGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: AppIconSize.md,
                    height: AppIconSize.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (icon case final glyph?)
                  Icon(glyph, size: AppIconSize.md),
                if (isLoading || icon != null)
                  const SizedBox(width: AppSpacing.sm),
                Flexible(child: Text(text, textAlign: TextAlign.center)),
              ],
            ),
          ),
        ),
      );
}

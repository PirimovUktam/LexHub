import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:shimmer/shimmer.dart';

/// SKELETON GRADIENTI — kulrang emas, KO'K-KULRANG.
///
/// NIMA UCHUN: `Colors.grey.shade200 → shade50` sweep'i "o'chgan ekran"
/// taassurotini beradi va ilovaning aksent rangi bilan bog'lanmaydi. Slate
/// shkalasi (ko'kka moyil kulrang) ayni fon rangi oilasidan, shuning uchun
/// yuklanish "vaqtincha holat" bo'lib ko'rinadi, "buzilgan" emas.
///
/// DIQQAT: bu gradient MAZMUN emas — u skeleton bloklarining maskasi.
/// Kontrast talabi bu yerga tegishli emas (matn yo'q), lekin gradient
/// fon bilan qo'shilib ketmasligi uchun eng to'q nuqta fon rangidan
/// farqlanadi.
LinearGradient _skeletonGradient(bool isDark) {
  final List<Color> colors = isDark
      ? const <Color>[
          AppColors.cardDark,
          Color(0xFF2A3A54), // slate 800 + ko'k moyillik
          AppColors.cardDark,
        ]
      : const <Color>[
          AppColors.borderLight,
          Color(0xFFF4F7FB), // deyarli oq, ko'kka moyil
          AppColors.borderLight,
        ];

  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
    stops: const <double>[0.1, 0.5, 0.9],
  );
}

/// Skeleton Shimmer Loading UI with dynamic legal status animation
class LegalAnalysisShimmer extends StatefulWidget {
  const LegalAnalysisShimmer({super.key});

  @override
  State<LegalAnalysisShimmer> createState() => _LegalAnalysisShimmerState();
}

class _LegalAnalysisShimmerState extends State<LegalAnalysisShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _currentStepIndex = 0;

  final List<String> _stages = [
    "Qonunchilik bazasidan moddalar qidirilmoqda...",
    "Lex.uz me'yoriy hujjatlari taqqoslanmoqda...",
    "Protsessual muddatlar va xavflar baholanmoqda...",
    "Oddiy tildagi xulosa va harakatlar rejasi tayyorlanmoqda...",
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addListener(() {
        final step = (_controller.value * _stages.length).floor();
        if (step != _currentStepIndex && step < _stages.length) {
          setState(() {
            _currentStepIndex = step;
          });
        }
      });
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live animated status banner
        ModernContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          backgroundColor: AppColors.indigo.withValues(alpha: 0.08),
          borderColor: AppColors.indigo.withValues(alpha: 0.25),
          child: Row(
            children: [
              // O'LCHANGAN DEFEKT: bu spinner — "javob hali kelmoqda"
              // holatining YAGONA grafik signali, ya'ni 1.4.11 bo'yicha 3:1
              // talab qiladi. XOM `indigo` O'Z tintining (`indigo@0.08`)
              // ustida qorong'ida 3.01:1 — aynan chegarada turardi: tint
              // alfasi bir qadam quyuqlashsa yiqilardi. Ton: 5.69 / 6.75.
              // Matn rangi (`indigoDark`/`indigoLight`) o'lchandi — 5.69 /
              // 12.04, ya'ni AA'dan yuqori, shuning uchun TEGILMADI.
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTone.accentIndigo.on(isDark),
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Text(
                  _stages[_currentStepIndex],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.indigoLight : AppColors.indigoDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const Gap(16),

        // Shimmer Skeleton Blocks
        //
        // ACCESSIBILITY: `enabled` — `reduce motion` yoqilgan bo'lsa sweep
        // TO'XTAYDI (skeleton statik ko'rinadi). Bu takrorlanuvchi animatsiya,
        // ya'ni vestibulyar buzilishi bor foydalanuvchi uchun majburiy shart.
        Shimmer(
          gradient: _skeletonGradient(isDark),
          enabled: AppMotion.loopAllowed(context),
          child: Column(
            children: [
              // Summary card skeleton
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
              const Gap(14),

              // Actionable steps skeleton
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
              const Gap(14),

              // Legal basis skeleton
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
              const Gap(14),

              // Risk assessment skeleton
              Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

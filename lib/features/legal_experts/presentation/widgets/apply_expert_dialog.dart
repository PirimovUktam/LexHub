import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/expert_labels.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_bloc.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_event.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_state.dart';

class ApplyExpertDialog extends StatefulWidget {
  const ApplyExpertDialog({super.key});

  @override
  State<ApplyExpertDialog> createState() => _ApplyExpertDialogState();
}

class _ApplyExpertDialogState extends State<ApplyExpertDialog> {
  final _formKey = GlobalKey<FormState>();
  final _specializationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _workplaceController = TextEditingController();
  final _educationController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _feeController = TextEditingController();

  // XOM DB QIYMATLARI (§16): bu satrlar `SubmitExpertApplicationEvent`
  // orqali `apply_for_expert_verification` RPC'ga QIYMAT sifatida ketadi,
  // shuning uchun TARJIMA QILINMAYDI. Ekranda ko'rinadigan matn
  // `expertApplySpecializationLabel()` orqali beriladi.
  static const List<String> _specializations = [
    "Mehnat huquqi",
    "Oila va Mulk huquqi",
    "Jinoyat va Tergov himoyasi",
    "Yo'l harakati va Ma'muriy jarimalar",
    "Iste'molchi huquqlari va Shartnomalar",
    "Biznes va Korporativ huquq",
    "Soliq va Bojxona huquqi",
  ];

  @override
  void dispose() {
    _specializationController.dispose();
    _experienceController.dispose();
    _workplaceController.dispose();
    _educationController.dispose();
    _licenseNumberController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final spec = _specializationController.text.trim();
      final exp = int.tryParse(_experienceController.text.trim()) ?? 1;
      final workplace = _workplaceController.text.trim();
      final education = _educationController.text.trim();
      final licenseNum = _licenseNumberController.text.trim();
      final fee = double.tryParse(_feeController.text.trim()) ?? 0.0;

      context.read<LegalExpertsBloc>().add(
            SubmitExpertApplicationEvent(
              specialization: spec,
              experienceYears: exp,
              licenseNumber: licenseNum,
              workplace: workplace.isNotEmpty ? workplace : null,
              education: education.isNotEmpty ? education : null,
              consultationFee: fee,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return BlocListener<LegalExpertsBloc, LegalExpertsState>(
      listener: (context, state) {
        if (state is ExpertApplicationSuccess) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              // O'LCHANGAN: `snackBarTheme` matnni oq qilib qulflaydi —
              // `emerald` ustida 2.54:1. `emeraldStrong`: 7.68:1.
              backgroundColor: AppColors.emeraldStrong,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is ExpertApplicationError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorStateText(context.l10n, state.message, state.code)),
              // O'LCHANGAN: oq matn `crimson` ustida 3.76:1 -> 6.47:1.
              backgroundColor: AppColors.emergencyStrong,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      // O'LCHANGAN DEFEKT (eng qattig'i): `primary`
                      // (#0F172A) qorong'i mavzuda `surfaceDark` bilan AYNI
                      // rang — dialog foni ham `surfaceDark`. Ya'ni plita
                      // foni (`primary@0.1`) ham, ikonkaning O'ZI ham fon
                      // bilan 1.00:1 edi: ikonka QORONG'IDA MUTLAQO
                      // KO'RINMASDI. Neytral ton: yorug' tomon PIKSELMA-
                      // PIKSEL o'zgarmaydi (`textPrimaryLight` == `primary`,
                      // 14.54:1), qorong'ida 8.09:1.
                      decoration: BoxDecoration(
                        color: AppTone.neutral.bg(isDark, alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: AppTone.neutral.on(isDark),
                        size: 24,
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Text(
                        l10n.expertApplyTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(16),
                Text(
                  l10n.expertApplyIntro,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const Gap(20),

                // Specialization
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: l10n.expertApplySpecializationLabel,
                    prefixIcon: const Icon(Icons.gavel_rounded),
                  ),
                  items: _specializations
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(expertApplySpecializationLabel(l10n, s)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) _specializationController.text = val;
                  },
                  validator: (v) => v == null || v.isEmpty
                      ? l10n.expertApplySpecializationError
                      : null,
                ),
                const Gap(14),

                // License Number
                TextFormField(
                  controller: _licenseNumberController,
                  decoration: InputDecoration(
                    labelText: l10n.expertApplyLicenseLabel,
                    prefixIcon: const Icon(Icons.badge_rounded),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? l10n.expertApplyLicenseError
                      : null,
                ),
                const Gap(14),

                // Experience Years
                TextFormField(
                  controller: _experienceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.expertApplyExperienceLabel,
                    prefixIcon: const Icon(Icons.work_history_rounded),
                  ),
                  validator: (v) => v == null || int.tryParse(v.trim()) == null
                      ? l10n.expertApplyExperienceError
                      : null,
                ),
                const Gap(14),

                // Workplace
                TextFormField(
                  controller: _workplaceController,
                  decoration: InputDecoration(
                    labelText: l10n.expertApplyWorkplaceLabel,
                    prefixIcon: const Icon(Icons.business_rounded),
                  ),
                ),
                const Gap(14),

                // Consultation Fee
                TextFormField(
                  controller: _feeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.expertApplyFeeLabel,
                    prefixIcon: const Icon(Icons.payments_rounded),
                  ),
                ),
                const Gap(24),

                // Actions
                BlocBuilder<LegalExpertsBloc, LegalExpertsState>(
                  builder: (context, state) {
                    final isLoading = state is ExpertApplicationSubmitting;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                          child: Text(l10n.actionCancel),
                        ),
                        const Gap(8),
                        ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          // RANG OVERRIDE'I O'CHIRILDI: `primary` fon
                          // qorong'ida dialog foni (`surfaceDark`) bilan AYNI
                          // rang bo'lib, tugmaning CHEGARASI 1.00:1 edi —
                          // tugma shakli ko'rinmasdi (1.4.11). Mavzuning
                          // `elevatedButtonTheme` si allaqachon to'g'ri
                          // juftlikni beradi: yorug' `primary`+oq (17.85:1),
                          // qorong'i `indigoDark`+oq (6.29:1). Faqat `shape`
                          // saqlanadi.
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(l10n.expertApplySubmit),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

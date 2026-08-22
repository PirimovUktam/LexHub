import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/expert_labels.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
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
              backgroundColor: AppColors.emerald,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is ExpertApplicationError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorStateText(context.l10n, state.message, state.code)),
              backgroundColor: AppColors.crimson,
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
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.primary,
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/localization/expert_labels.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application_cooldown.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_bloc.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_event.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/legal_experts_state.dart';

/// SOVUTISH DAVRI MATNI — HAR TILDA TO'LIQ.
///
/// NUQSON (2026-08-30 da tuzatildi): rad etish SABABI va qayta topshirish
/// VAQTI faqat server xato MATNI ichida edi. `errorStateText` server matnini
/// FAQAT `uz` uchun ishlatadi, boshqa tilda `FailureCode` bo'yicha UMUMIY
/// ARB matnini beradi — ya'ni ingliz UI'da sabab HAM, vaqt HAM YO'QOLARDI.
///
/// Endi server ayni ikki qiymatni mashina o'qiy oladigan `DETAIL` JSON
/// shaklida yuboradi (`20260830070000_expert_cooldown_machine_readable.sql`)
/// va matn SHU YERDA, foydalanuvchi tilida quriladi (§16: shablon tarjima
/// qilinadi, qiymat — xom ma'lumot).
///
/// `cooldown == null` (eski server yoki shakl mos kelmadi) -> avvalgi
/// xatti-harakat: `errorStateText`. Ya'ni PASAYISH YO'Q.
///
/// SABAB YO'Q bo'lsa `reason` shoxi ISHLATILMAYDI — bo'sh "Sabab:"
/// sarlavhasi ko'rsatilmaydi (§20). Bu serverning ikki `RAISE` shoxiga
/// aynan mos keladi.
String expertCooldownText(
  AppL10n l10n,
  String message,
  FailureCode code,
  ExpertApplicationCooldown? cooldown,
) {
  if (cooldown == null) return errorStateText(l10n, message, code);

  // Sana shakli SONLI va lokaldan mustaqil (loyihadagi mavjud konvensiya:
  // `question_detail_page.dart`). `retryAt` mapper'da allaqachon MAHALLIY
  // vaqtga aylantirilgan — serverdagi UTC xom matni ko'rsatilmaydi.
  final time = DateFormat('dd.MM.yyyy, HH:mm').format(cooldown.retryAt);
  final reason = cooldown.reason;

  if (reason == null) return l10n.errorApplicationCooldownUntil(time);
  return l10n.errorApplicationCooldownUntilWithReason(reason, time);
}

/// MUVAFFAQIYAT MATNI — `failure_text.dart` bilan AYNI mantiq.
///
/// Server `apply_for_expert_verification` javobida o'z `message`ini beradi.
/// O'ZBEK tilida u AYNAN ko'rsatiladi (muallif yozgan, aniqroq), boshqa
/// tilda o'zbekcha matn ko'rsatish MA'NOSIZ — ARB matni olinadi.
/// Server matn bermasa (`''`) — har ikki tilda ham ARB matni.
String expertApplySuccessText(AppL10n l10n, String message) {
  final authored = message.trim();
  if (l10n.localeName.startsWith('uz') && authored.isNotEmpty) return authored;
  return l10n.expertApplySuccess;
}

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
              content: Text(expertApplySuccessText(l10n, state.message)),
              // O'LCHANGAN: `snackBarTheme` matnni oq qilib qulflaydi —
              // `emerald` ustida 2.54:1. `emeraldStrong`: 7.68:1.
              backgroundColor: AppColors.emeraldStrong,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is ExpertApplicationError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(expertCooldownText(
                context.l10n,
                state.message,
                state.code,
                state.cooldown,
              )),
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
                const Gap(12),

                // OSHKORALIK OGOHLANTIRISHI — RAZILIK ARIZADAN OLDIN.
                //
                // NIMA UCHUN: ariza tasdiqlanganidan keyin foydalanuvchi
                // `public_expert_profiles_view` ga tushadi, view esa `p.phone`
                // ni HAM beradi va unga `anon` uchun SELECT berilgan
                // (`20260829000500_expert_license_visibility_and_lock.sql:63`
                // va `:85`). Ya'ni SHAXSIY telefon raqami tizimga KIRMAGAN
                // mehmonga ham ko'rinadi; ilova uni ko'rsatadi va undan
                // qo'ng'iroq qiladi (`expert_profile_modal.dart:426-429`,
                // `tel:` havolasi). Ilgari bu oyna bu haqda HECH NIMA
                // demasdi — foydalanuvchi shaxsiy raqami e'lon qilinishini
                // BILMASDAN tasdiqlanardi.
                //
                // Server kontrakti, view va RLS TEGILMAYDI — ochiq katalog
                // ATAYLAB shunday (mahsulot talabi). Faqat foydalanuvchi
                // OLDINDAN xabardor qilinadi.
                //
                // KONTRAST (o'lchangan, yangi da'vo emas): `AppTone.warning`
                // tinti ustidagi matn yorug'da min 5.86:1 (`surfaceLight` =
                // #FFFFFF band ichida), qorong'ida min 7.07:1 — eng yomon
                // holat `cardDark` (#1E293B). Dialog yuzasi `surfaceDark`
                // (#0F172A) har bir kanalda `cardDark` dan QORONG'I, ya'ni
                // yorug' matn uchun kontrast faqat OSHADI. Alfa (0.10/0.16)
                // o'lchangan 0..0.20 bandi ichida. Qulf:
                // `test/core/theme/color_contrast_test.dart`.
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTone.warning.bg(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTone.warning.border(isDark)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.public_rounded,
                        size: 18,
                        color: AppTone.warning.on(isDark),
                      ),
                      const Gap(10),
                      Expanded(
                        child: Text(
                          l10n.expertApplyPublicNotice,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTone.warning.on(isDark),
                          ),
                        ),
                      ),
                    ],
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

/// ARIZA MODERATSIYASI EKRANI (P0).
///
/// ── NIMA UCHUN BU EKRAN BOR ──
///
/// `apply_for_expert_verification()` RPC ariza qabul qiladi, `expert_profiles`
/// ga qator yozadi va `verified_at` ni NULL qoldiradi. Katalog esa
/// `public_expert_profiles_view` dan o'qiydi — u `p.is_verified = TRUE`
/// talab qiladi. Ya'ni ariza topshirilgandan keyin uni TASDIQLAYDIGAN
/// birorta ham UI YO'Q edi: `verify_expert_application()` RPC yozilgan,
/// lekin uni chaqiradigan ekran mavjud emasdi. Natijada advokatlar katalogi
/// hech qachon to'lmasdi va "tasdiqlangan advokat" oqimi boshi berk edi.
///
/// ── XAVFSIZLIK CHEGARASI ──
///
/// Bu ekranning ko'rinishi (`profile_tab_page.dart` dagi rol tekshiruvi)
/// FAQAT UX. Haqiqiy chegara SERVERDA:
///   * `expert_profiles` SELECT RLS — `auth.uid() = user_id OR
///     public.is_admin_or_moderator()`, ya'ni admin bo'lmagan foydalanuvchi
///     bu ekranni ochsa FAQAT o'z arizasini ko'radi;
///   * `verify_expert_application()` — `is_admin_or_moderator()` bo'lmasa
///     `RAISE EXCEPTION 'Access Denied: ...'`.
/// APK'ni o'zgartirib ekranni zo'rlab ochish hech narsa bermaydi.
///
/// ── HALOLLIK CHEGARALARI (§6, §20) ──
///
/// 1. BO'SH MAYDON TO'QILMAYDI. Litsenziya raqami yoki ish joyi bo'sh
///    bo'lsa `moderationFieldMissing` chiqadi. Moderator nuqsonni KO'RISHI
///    kerak — "namuna" qiymat uni yolg'on asosda tasdiqlashga olib borardi.
/// 2. RAD ETISHNING HAQIQIY OQIBATI AYTILADI. Rad etish endi bazada HOLAT
///    QOLDIRADI: `verify_expert_application(p_approve => FALSE)`
///    `expert_profiles.rejected_at` ni yozadi va `profiles.is_verified` ni
///    FALSE qiladi. Dialog buni `moderationRejectConsequence` bilan aytadi.
///
///    RUNTIME'DA O'LCHANGAN (2026-08-29, Studio, tranzaksiya ichida va
///    oxirida qaytarilgan): tasdiqlashdan keyin `role=verified_expert`,
///    `is_verified=t`, ochiq katalogda 1 qator; rad etishdan keyin
///    `role=citizen`, `is_verified=f`, `rejected_at` yozilgan, katalogda 0
///    qator, kutayotgan arizalar 0. Qayta topshirish `rejected_at` ni
///    tozalaydi (kutayotganlar yana 1) va tasdiqlangan advokatning
///    `license_number` qulfi saqlanadi.
///
///    HALI SINALMAGAN: ilova -> PostgREST -> RPC yo'li va HAQIQIY admin JWT.
///    Yuqoridagi o'lchov `postgres` sessiyasida, `auth.uid()` `set_config`
///    bilan simulyatsiya qilib olingan.

/// 3. RO'YXAT YANGILANMASA — SHUNDAY DEYILADI. RPC o'tib, qayta o'qish
///    yiqilsa `listRefreshed == false` va SnackBar boshqa matn beradi.
/// 4. LITSENZIYA HUJJATI (PII) faqat SHU ekranda va faqat server ruxsat
///    bergan qatorlar uchun ko'rinadi — ochiq katalog view'ida u YO'Q.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/expert_moderation_bloc.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/expert_moderation_event.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/expert_moderation_state.dart';
import 'package:url_launcher/url_launcher.dart';

class ExpertModerationPage extends StatelessWidget {
  const ExpertModerationPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => const ExpertModerationPage(),
      );

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ExpertModerationBloc>(
      create: (_) => sl<ExpertModerationBloc>()
        ..add(const LoadPendingApplicationsEvent()),
      child: const _ModerationView(),
    );
  }
}
class _ModerationView extends StatelessWidget {
  const _ModerationView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moderationTitle)),
      body: BlocConsumer<ExpertModerationBloc, ExpertModerationState>(
        listenWhen: (previous, current) =>
            current is ExpertModerationActionDone ||
            current is ExpertModerationActionFailed,
        listener: _onStateChanged,
        builder: (context, state) {
          if (state is ExpertModerationLoading ||
              state is ExpertModerationInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ExpertModerationError) {
            return _ErrorBody(message: state.message, code: state.code);
          }

          final applications = _applicationsOf(state);
          final busyUserId =
              state is ExpertModerationInProgress ? state.targetUserId : null;

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<ExpertModerationBloc>()
                  .add(const LoadPendingApplicationsEvent());
            },
            child: applications.isEmpty
                ? const _EmptyBody()
                : _ApplicationList(
                    applications: applications,
                    busyUserId: busyUserId,
                  ),
          );
        },
      ),
    );
  }

  static List<ExpertApplication> _applicationsOf(ExpertModerationState state) {
    if (state is ExpertModerationLoaded) return state.applications;
    if (state is ExpertModerationInProgress) return state.applications;
    if (state is ExpertModerationActionDone) return state.applications;
    if (state is ExpertModerationActionFailed) return state.applications;
    return const <ExpertApplication>[];
  }

  static void _onStateChanged(
    BuildContext context,
    ExpertModerationState state,
  ) {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (state is ExpertModerationActionFailed) {
      messenger.showSnackBar(SnackBar(
        content: Text(errorStateText(
          l10n,
          state.message,
          state.code ?? FailureCode.unknown,
        )),
        backgroundColor: AppTone.danger.on(false),
      ));
      return;
    }

    if (state is! ExpertModerationActionDone) return;

    final name = state.fullName.trim().isEmpty
        ? l10n.moderationUnnamedApplicant
        : state.fullName;
    final done = state.approved
        ? l10n.moderationApprovedToast(name)
        : l10n.moderationRejectedToast(name);

    // ROL BEKOR QILINGANI AYTILADI. Tasdiqlangan advokat rad etilsa server uni
    // `citizen` ga qaytaradi — bu arizani rad etishdan KO'RA og'irroq oqibat.
    // Aytmaslik moderatordan haqiqiy natijani yashirardi (§20): u faqat
    // "ariza rad etildi" deb o'ylab, advokatning katalogdan chiqib ketganini
    // bilmay qolardi. Belgi SERVERDAN keladi (`role_reverted`), klient
    // hisoblamaydi.
    //
    // RO'YXAT ESKIRGANINI HAM YASHIRMAYMIZ: RPC o'tdi, lekin qayta o'qish
    // yiqildi — moderator ekrandagi ro'yxatga to'liq ishonmasligi kerak.
    final parts = <String>[
      done,
      if (state.roleReverted) l10n.moderationRoleReverted,
      if (!state.listRefreshed) l10n.moderationListStale,
    ];

    messenger.showSnackBar(SnackBar(
      content: Text(parts.join(' ')),
      backgroundColor: state.approved
          ? AppTone.success.on(false)
          : AppTone.neutral.on(false),
    ));
  }
}
class _ApplicationList extends StatelessWidget {
  final List<ExpertApplication> applications;
  final String? busyUserId;

  const _ApplicationList({required this.applications, this.busyUserId});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: applications.length + 1,
      separatorBuilder: (_, __) => const Gap(AppSpacing.md),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              l10n.moderationPendingCount(applications.length),
              style: theme.textTheme.titleSmall,
            ),
          );
        }

        final application = applications[index - 1];
        return _ApplicationCard(
          application: application,
          busy: busyUserId == application.userId,
        );
      },
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const Gap(AppSpacing.md),
                Text(
                  l10n.moderationEmptyTitle,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const Gap(AppSpacing.xs),
                Text(
                  l10n.moderationEmptyBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _ErrorBody extends StatelessWidget {
  final String message;
  final FailureCode? code;

  const _ErrorBody({required this.message, this.code});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppTone.danger.on(isDark),
            ),
            const Gap(AppSpacing.md),
            Text(
              // Xom server matni EMAS: `errorStateText` o'zbek tilida
              // muallif yozgan sanitizatsiya qilingan matnni, boshqa tilda
              // `FailureCode` bo'yicha ARB tarjimasini beradi.
              errorStateText(l10n, message, code ?? FailureCode.unknown),
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const Gap(AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => context
                  .read<ExpertModerationBloc>()
                  .add(const LoadPendingApplicationsEvent()),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}
class _ApplicationCard extends StatelessWidget {
  final ExpertApplication application;

  /// Shu ariza uchun RPC ketgan va javob kelmagan. Tugmalar o'chiriladi —
  /// ikki marta bosish ikki RPC chaqiruvini yuborardi.
  final bool busy;

  const _ApplicationCard({required this.application, required this.busy});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final name = application.fullName.trim().isEmpty
        ? l10n.moderationUnnamedApplicant
        : application.fullName;

    return ModernContainer(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: theme.textTheme.titleMedium),
          if (application.createdAt != null) ...[
            const Gap(AppSpacing.xxs),
            Text(
              l10n.moderationSubmittedAt(_formatDate(application.createdAt!)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const Gap(AppSpacing.md),
          _Field(
            label: l10n.moderationLicenseLabel,
            value: application.licenseNumber,
          ),
          _Field(
            label: l10n.moderationSpecializationLabel,
            value: application.specialization,
          ),
          _Field(
            label: l10n.moderationExperienceLabel,
            value: l10n.moderationExperienceValue(application.experienceYears),
          ),
          _Field(
            label: l10n.moderationWorkplaceLabel,
            value: application.workplace,
          ),
          _Field(
            label: l10n.moderationEducationLabel,
            value: application.education,
          ),
          const Gap(AppSpacing.md),
          _DocumentRow(application: application, isDark: isDark),
          const Gap(AppSpacing.md),
          _ActionRow(application: application, busy: busy, name: name),
        ],
      ),
    );
  }

  /// Lokaldan mustaqil qisqa sana. `intl` `DateFormat` ATAYLAB ishlatilmadi:
  /// bu yerda kerak bo'lgani — arizaning yoshi, uzun lokalizatsiyalangan
  /// sana emas.
  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }
}
/// Bitta maydon satri. BO'SH qiymat `moderationFieldMissing` bo'lib,
/// OGOHLANTIRISH tonida chiqadi — moderator nuqsonni ko'rishi kerak (§6).
class _Field extends StatelessWidget {
  final String label;
  final String value;

  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final missing = value.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Text(
              missing ? l10n.moderationFieldMissing : value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: missing ? AppTone.warning.on(isDark) : null,
                fontStyle: missing ? FontStyle.italic : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/// LITSENZIYA HUJJATI (PII) satri.
///
/// Hujjat YO'Q bo'lsa bu OSHKORA aytiladi — tugmani jimgina yashirish
/// moderatorga "tekshirishga hech narsa yo'q" degan noto'g'ri taassurot
/// berardi, aslida esa tekshiruvsiz tasdiqlash xavfi bor.
class _DocumentRow extends StatelessWidget {
  final ExpertApplication application;
  final bool isDark;

  const _DocumentRow({required this.application, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    if (!application.hasLicenseDocument) {
      return Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppTone.warning.on(isDark),
          ),
          const Gap(AppSpacing.xs),
          Expanded(
            child: Text(
              l10n.moderationNoDocument,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTone.warning.on(isDark),
              ),
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _open(context, application.licenseDocumentUrl!),
        icon: const Icon(Icons.description_outlined, size: 18),
        label: Text(l10n.moderationOpenDocument),
      ),
    );
  }

  static Future<void> _open(BuildContext context, String rawUrl) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(rawUrl.trim());

    // JIM NOSOZLIK YO'Q: URL buzuq bo'lsa yoki tashqi ilova ochilmasa
    // foydalanuvchi buni KO'RADI. `catch (_) {}` ishlatilmaydi (§20).
    var opened = false;
    if (uri != null && uri.hasScheme) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on PlatformException catch (_) {
        opened = false;
      }
    }

    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.moderationDocumentOpenFailed)),
      );
    }
  }
}
class _ActionRow extends StatelessWidget {
  final ExpertApplication application;
  final bool busy;
  final String name;

  const _ActionRow({
    required this.application,
    required this.busy,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (busy) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _confirm(context, approve: false),
            child: Text(l10n.moderationReject),
          ),
        ),
        const Gap(AppSpacing.sm),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _confirm(context, approve: true),
            child: Text(l10n.moderationApprove),
          ),
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context, {required bool approve}) async {
    final l10n = context.l10n;
    final bloc = context.read<ExpertModerationBloc>();

    // Kontroller DIALOGDAN uzoq yashashi kerak: matn dialog YOPILGANDAN
    // keyin o'qiladi. Shuning uchun u shu metodda yaratiladi va `finally`
    // da `dispose` qilinadi (aks holda har rad etishda bitta
    // `TextEditingController` sizib qolardi).
    final TextEditingController? reasonController =
        approve ? null : TextEditingController();

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          // Sabab maydoni + klaviatura ochilganda dialog balandligi
          // yetmasligi mumkin. FAQAT rad etish yo'lida yoqiladi —
          // tasdiqlash dialogi o'zgarmaydi.
          scrollable: !approve,
          title: Text(
            approve ? l10n.moderationApproveTitle : l10n.moderationRejectTitle,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                approve
                    ? l10n.moderationApproveBody(name)
                    : l10n.moderationRejectBody(name),
              ),
              // RAD ETISHNING HAQIQIY OQIBATI. Ariza ro'yxatdan CHIQADI
              // (`rejected_at` yoziladi) va arizachi tuzatib qayta topshira
              // oladi — moderator ikkinchi qismini bilishi kerak, aks holda
              // qayta paydo bo'lgan arizani nosozlik deb o'ylardi.
              if (!approve) ...[
                const Gap(AppSpacing.sm),
                Text(
                  l10n.moderationRejectConsequence,
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const Gap(AppSpacing.md),
                // SABAB — MAJBURIY EMAS (server `DEFAULT NULL` qabul qiladi).
                // `maxLength` server CHECK'i bilan AYNI: 1..500 belgi
                // (`expert_profiles_rejection_reason_len`). Chegara UI'da
                // ko'rsatilmasa moderator uzun matn yozib 400 olardi.
                TextField(
                  controller: reasonController,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.moderationRejectReasonLabel,
                    hintText: l10n.moderationRejectReasonHint,
                    helperText: l10n.moderationRejectReasonDelivery,
                    helperMaxLines: 3,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.actionCancel),
            ),
            // `ElevatedButton` ATAYLAB (`FilledButton` EMAS): loyihada
            // tasdiqlash dialoglari birlamchi harakat uchun aynan shu tugmani
            // ishlatadi (`my_consultations_page.dart`), va qorong'i mavzuda
            // `elevatedButtonTheme` ham `filledButtonTheme` ham bir xil
            // `indigoDark` + oq (6.29:1) beradi — ya'ni ko'rinish farqi YO'Q,
            // faqat konventsiya. Regression guard:
            // test/core/theme/input_border_contrast_test.dart
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                approve ? l10n.moderationApprove : l10n.moderationReject,
              ),
            ),
          ],
        ),
      );

      if (ok != true) return;
      bloc.add(ModerateApplicationEvent(
        userId: application.userId,
        approve: approve,
        // Bo'sh/oraliqli matnni datasource NULL ga aylantiradi — server
        // CHECK'i bo'sh satrni rad etardi.
        rejectionReason: reasonController?.text,
      ));
    } finally {
      reasonController?.dispose();
    }
  }
}

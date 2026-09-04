import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/consultation_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_bloc.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_event.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_state.dart';

class MyConsultationsPage extends StatelessWidget {
  const MyConsultationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ConsultationBloc>()..add(const LoadMyConsultationsEvent()),
      child: const _MyConsultationsView(),
    );
  }
}

class _MyConsultationsView extends StatelessWidget {
  const _MyConsultationsView();

  void _showCancelDialog(BuildContext context, Consultation consultation) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final hoursUntil =
        consultation.scheduledAt.difference(DateTime.now()).inHours;
    double refundPercent = 0;
    if (hoursUntil > 24) {
      refundPercent = 100;
    } else if (hoursUntil >= 2) {
      refundPercent = 80;
    } else {
      refundPercent = 0;
    }
    final refundAmount = consultation.priceAmountUzs * (refundPercent / 100);

    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.consultationCancelTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.consultationCancelHoursLeft(hoursUntil),
              style: theme.textTheme.bodyMedium,
            ),
            const Gap(8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTone.success.bg(isDark, alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              // O'LCHANGAN: bu PUL summasi — bekor qilish qarorini
              // belgilaydigan matn, xom `emerald` bilan o'z 12% tintida
              // 2.27:1 edi. Ton: 6.86 / 7.76.
              child: Text(
                l10n.consultationCancelRefundLine(
                  refundPercent.toStringAsFixed(0),
                  refundAmount.toStringAsFixed(0),
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTone.success.on(isDark),
                ),
              ),
            ),
            const Gap(14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: l10n.consultationCancelReasonLabel,
                hintText: l10n.consultationCancelReasonHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.actionClose),
          ),
          ElevatedButton(
            // O'LCHANGAN: fon `crimson` (#EF4444) + mavzuning OQ yorlig'i
            // 3.76:1 — 14 px qalin matn "yirik" emas, ya'ni AA 4.5:1 dan
            // past. `crimsonDark` (#DC2626): 4.83:1. Ogohlantiruvchi qizil
            // xarakter saqlanadi.
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.crimsonDark),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<ConsultationBloc>().add(
                    CancelConsultationEvent(
                      consultationId: consultation.id,
                      // XOM DB QIYMATI (§16): bu matn `cancel_consultation(
                      // p_reason)` ga uzatiladi va `consultations.
                      // cancellation_reason` ga YOZILADI — ya'ni UI yorlig'i
                      // emas, ma'lumot. Datasource'dagi default bilan bir xil
                      // bo'lishi shart, shuning uchun TARJIMA QILINMAYDI.
                      reason: reasonController.text.trim().isNotEmpty
                          ? reasonController.text.trim()
                          : "Foydalanuvchi tomonidan bekor qilindi",
                    ),
                  );
            },
            child: Text(
              l10n.consultationCancelConfirm,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.myConsultationsTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          bottom: TabBar(
            // O'LCHANGAN: qorong'i mavzuda yorliq `indigo` (#6366F1)
            // `surfaceDark` ustida 4.00:1 — tab yorlig'i MATN, ya'ni AA
            // 4.5:1 talab qiladi. `indigoOnTintDark`: 8.96:1. Yorug' tomon
            // `primary` bilan 17.85:1 — o'zgarmaydi.
            indicatorColor:
                isDark ? AppColors.indigoOnTintDark : AppColors.primary,
            labelColor: isDark ? AppColors.indigoOnTintDark : AppColors.primary,
            tabs: [
              Tab(text: l10n.myConsultationsTabUpcoming),
              Tab(text: l10n.myConsultationsTabCompleted),
              Tab(text: l10n.myConsultationsTabCancelled),
            ],
          ),
        ),
        body: BlocConsumer<ConsultationBloc, ConsultationState>(
          listener: (context, state) {
            if (state is ConsultationCancelledState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    l10n.consultationCancelledSnack(
                      state.refundAmountUzs.toStringAsFixed(0),
                    ),
                  ),
                  // O'LCHANGAN: SnackBar matni OQ, fon `emerald` — 2.54:1.
                  // `emeraldStrong`: 7.68:1.
                  backgroundColor: AppColors.emeraldStrong,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is ConsultationLoadingState) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is MyConsultationsLoadedState) {
              final upcoming = state.consultations
                  .where((c) =>
                      c.status == ConsultationStatus.confirmed ||
                      c.status == ConsultationStatus.awaitingPayment ||
                      c.status == ConsultationStatus.inProgress ||
                      c.status == ConsultationStatus.pending)
                  .toList();

              final completed = state.consultations
                  .where((c) => c.status == ConsultationStatus.completed)
                  .toList();

              final cancelled = state.consultations
                  .where((c) =>
                      c.status == ConsultationStatus.cancelled ||
                      c.status == ConsultationStatus.expired ||
                      c.status == ConsultationStatus.disputed)
                  .toList();

              return TabBarView(
                children: [
                  _buildList(context, upcoming, isDark, isUpcoming: true),
                  _buildList(context, completed, isDark),
                  _buildList(context, cancelled, isDark),
                ],
              );
            }

            return TabBarView(
              children: [
                _buildList(context, [], isDark, isUpcoming: true),
                _buildList(context, [], isDark),
                _buildList(context, [], isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Consultation> items,
    bool isDark, {
    bool isUpcoming = false,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 56,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const Gap(14),
            Text(
              context.l10n.myConsultationsEmpty,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Gap(12),
      itemBuilder: (context, index) {
        final c = items[index];
        final l10n = context.l10n;
        return ModernContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      // §6: TO'QIMA ISM YO'Q. Ilgari server ism bermasa
                      // "Tasdiqlangan Yurist" deb YOZILARDI — ya'ni UI
                      // tasdiqlanganlik haqida O'ZI da'vo qilardi.
                      (c.expertName == null || c.expertName!.trim().isEmpty)
                          ? l10n.expertNameUnknown
                          : c.expertName!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _buildStatusChip(l10n, c.status, isDark),
                ],
              ),
              if (c.specialization != null) ...[
                const Gap(3),
                Text(
                  c.specialization!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
              const Divider(height: 20),
              Row(
                children: [
                  // O'LCHANGAN: 4.47 (yorug') / 3.27:1 (qorong'i).
                  // Ton: 6.29 / 7.34.
                  Icon(Icons.access_time_rounded,
                      size: 16, color: AppTone.accentIndigo.on(isDark)),
                  const Gap(6),
                  Text(
                    "${c.scheduledAt.day}.${c.scheduledAt.month}.${c.scheduledAt.year} | ${c.scheduledAt.hour.toString().padLeft(2, '0')}:${c.scheduledAt.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    consultationAmountLabel(l10n, c.priceAmountUzs),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      // O'LCHANGAN: NARX — 14 px qalin, `amberDark` oq karta
                      // ustida 3.19:1 (AA'dan past). Ton: 7.09 / 10.15.
                      color: AppTone.warning.on(isDark),
                    ),
                  ),
                ],
              ),
              if (isUpcoming) ...[
                const Gap(16),
                Row(
                  children: [
                    if (c.meetingLink != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.consultationMeetingLinkSnack(
                                    c.meetingLink!,
                                  ),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            // O'LCHANGAN: OQ yorliq `emerald` fonida
                            // 2.54:1. `emeraldStrong`: 7.68:1.
                            backgroundColor: AppColors.emeraldStrong,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(40),
                          ),
                          icon: const Icon(Icons.videocam_rounded, size: 18),
                          label: Text(l10n.consultationJoinRoom),
                        ),
                      ),
                    if (c.meetingLink != null) const Gap(10),
                    OutlinedButton(
                      onPressed: () => _showCancelDialog(context, c),
                      style: OutlinedButton.styleFrom(
                        // `minimumSize` MAJBURAN beriladi — mavzudagi
                        // `Size.fromHeight(50)` = `Size(infinity, 50)` va bu
                        // tugma `Row` ning flex BO'LMAGAN uyasida turadi, ya'ni
                        // cheksiz kenglik oladi -> layout yiqiladi (AYNI sabab
                        // `apply_expert_dialog.dart:408` da JONLI o'lchandi).
                        // 64 = Material standarti, 50 = mavzudagi balandlik.
                        minimumSize: const Size(64, 50),
                        // O'LCHANGAN: yorliq `crimson` — oq karta ustida
                        // 3.76:1, qorong'i kartada 3.89:1, ya'ni MATN uchun
                        // ikki mavzuda ham AA'dan past. Ton: 6.47 / 7.71.
                        // Kontur (grafik, 3:1) `crimson` bo'lib QOLADI:
                        // 3.76 / 3.89 — o'tadi va ogohlantiruvchi rang
                        // kodlashni saqlaydi.
                        foregroundColor: AppTone.danger.on(isDark),
                        side: const BorderSide(color: AppColors.crimson),
                      ),
                      child: Text(l10n.consultationCancelConfirm),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(AppL10n l10n, ConsultationStatus status, bool isDark) {
    Color color;
    switch (status) {
      case ConsultationStatus.confirmed:
        color = AppColors.emerald;
        break;
      case ConsultationStatus.awaitingPayment:
      case ConsultationStatus.pending:
        color = AppColors.amber;
        break;
      case ConsultationStatus.inProgress:
        color = AppColors.indigo;
        break;
      case ConsultationStatus.completed:
        color = AppColors.primary;
        break;
      case ConsultationStatus.cancelled:
      case ConsultationStatus.expired:
      case ConsultationStatus.disputed:
        color = AppColors.crimson;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // O'LCHANGAN DEFEKT: matn XOM aksent, foni AYNI aksentning 15%
        // tinti edi — 11 px qalin yorliq uchun (AA 4.5:1):
        //   `completed` (`primary`) qorong'ida 1.18:1 — KO'RINMASDI
        //   `amber`  yorug'da 1.92 | `emerald` yorug'da 2.20
        //   `indigo` qorong'ida 2.79 | `crimson` yorug'da 3.09
        // Ya'ni BESH holatdan birortasi ham ikki mavzuda o'tmasdi.
        // Ton ko'chirishidan keyin eng yomon qiymat 5.20:1. Rang kodlash
        // (yashil = tasdiq, qizil = bekor) saqlanadi.
        color: AppTone.forRawAccent(color).bg(isDark, alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTone.forRawAccent(color)
                .accent(isDark)
                .withValues(alpha: 0.4)),
      ),
      child: Text(
        consultationStatusLabel(l10n, status),
        style: TextStyle(
          color: AppTone.forRawAccent(color).on(isDark),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

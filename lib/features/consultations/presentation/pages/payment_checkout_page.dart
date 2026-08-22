import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/consultation_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation_slot.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_bloc.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_event.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_state.dart';

class PaymentCheckoutPage extends StatefulWidget {
  final PaymentCheckoutResult checkoutResult;

  const PaymentCheckoutPage({
    super.key,
    required this.checkoutResult,
  });

  @override
  State<PaymentCheckoutPage> createState() => _PaymentCheckoutPageState();
}

class _PaymentCheckoutPageState extends State<PaymentCheckoutPage> {
  String _selectedProvider = 'payme';

  // §16: bu ro'yxatda TARJIMA QILINADIGAN matn YO'Q.
  //   * `id`   — `payments.provider` ga yoziladigan XOM DB qiymati;
  //   * `name` — atoqli nom (brend), tarjima qilinmaydi;
  //   * tavsif — `paymentProviderSubtitle(l10n, id)` orqali ARB'dan olinadi.
  //
  // Ilgari tavsiflar shu yerda qotib qolgan va `'Humo, Uzcard orqali to''lov'`
  // Dart'da IKKI QO'SHNI LITERAL sifatida birlashib ("to" + "lov") ekranda
  // "Humo, Uzcard orqali to lov" ko'rinardi.
  static const List<Map<String, dynamic>> _providers = [
    {
      'id': 'payme',
      'name': 'Payme',
      'icon': Icons.credit_card_rounded,
      'color': AppColors.indigo,
    },
    {
      'id': 'click',
      'name': 'Click Up',
      'icon': Icons.account_balance_wallet_rounded,
      'color': AppColors.primary,
    },
    {
      'id': 'uzum',
      'name': 'Uzum Bank',
      'icon': Icons.shopping_bag_outlined,
      'color': AppColors.accent,
    },
  ];

  void _onPayPressed() {
    final bloc = context.read<ConsultationBloc>();
    bloc.add(
      ConfirmPaymentEvent(
        paymentId: widget.checkoutResult.paymentId,
        provider: _selectedProvider,
        providerTransactionId: 'tx_${_selectedProvider}_${DateTime.now().millisecondsSinceEpoch}',
        paidAmountTiyin: widget.checkoutResult.priceAmountTiyin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.paymentTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: BlocConsumer<ConsultationBloc, ConsultationState>(
        listener: (context, state) {
          if (state is ConsultationErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.crimson,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is PaymentProcessingState) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const Gap(16),
                  Text(
                    l10n.paymentProcessing,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }

          if (state is PaymentSuccessState) {
            return _buildSuccessView(context, l10n, isDark, state.meetingLink);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Summary Card
                ModernContainer(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.indigo : AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  // §6: server ism bermasa TO'QIMA ism YO'Q.
                                  widget.checkoutResult.expertName
                                          .trim()
                                          .isEmpty
                                      ? l10n.expertNameUnknown
                                      : widget.checkoutResult.expertName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Gap(3),
                                Text(
                                  // Ilgari "Huquqiy maslahat (45 daqiqa)" —
                                  // 45 daqiqa CLIENTDA qotib qolgan edi.
                                  // `PaymentCheckoutResult` davomiylikni
                                  // QAYTARMAYDI, shuning uchun raqam
                                  // KO'RSATILMAYDI (§6).
                                  l10n.paymentServiceLine,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.paymentScheduledDateLabel,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            "${widget.checkoutResult.scheduledAt.day}.${widget.checkoutResult.scheduledAt.month}.${widget.checkoutResult.scheduledAt.year} | ${widget.checkoutResult.scheduledAt.hour.toString().padLeft(2, '0')}:00",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Gap(10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.paymentTotalLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            consultationAmountLabel(
                              l10n,
                              widget.checkoutResult.priceAmountUzs,
                            ),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isDark ? AppColors.amber : AppColors.amberDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Gap(20),

                // Escrow & Refund Shield Guarantee
                ModernContainer(
                  backgroundColor: isDark
                      ? AppColors.emerald.withValues(alpha: 0.1)
                      : AppColors.emerald.withValues(alpha: 0.08),
                  borderColor: isDark
                      ? AppColors.emerald.withValues(alpha: 0.3)
                      : AppColors.emerald.withValues(alpha: 0.25),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: AppColors.emerald,
                        size: 26,
                      ),
                      const Gap(12),
                      Expanded(
                        child: Text(
                          l10n.paymentEscrowNotice,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Gap(24),

                Text(
                  l10n.paymentMethodTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const Gap(12),

                // Payment Provider Selector
                ..._providers.map((p) {
                  final providerId = p['id'] as String;
                  final isSelected = _selectedProvider == providerId;
                  final subtitle = paymentProviderSubtitle(l10n, providerId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedProvider = providerId;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: ModernContainer(
                        borderColor: isSelected
                            ? (p['color'] as Color)
                            : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        backgroundColor: isSelected
                            ? (p['color'] as Color).withValues(alpha: 0.08)
                            : null,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (p['color'] as Color).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                p['icon'] as IconData,
                                color: p['color'] as Color,
                                size: 22,
                              ),
                            ),
                            const Gap(14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['name'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Gap(2),
                                  if (subtitle != null)
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (p['color'] as Color)
                                      : (isDark ? Colors.white38 : Colors.black38),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: p['color'] as Color,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const Gap(28),

                // Pay Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _onPayPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.indigo : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.lock_rounded, size: 20),
                    label: Text(
                      l10n.paymentPayAmount(
                        widget.checkoutResult.priceAmountUzs
                            .toStringAsFixed(0),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Gap(24),
              ],
            ),
          );
        },
      ),
    );
  }

  /// §6: `meetingLink` NULLABLE — TO'QIMA HAVOLA YO'Q.
  ///
  /// `process_payment_webhook` uchrashuv havolasini faqat to'lov BIRINCHI
  /// marta tasdiqlanganda qaytaradi; takroriy (idempotent) chaqiruvda
  /// `meeting_link` javobda BO'LMAYDI. Ilgari bloc bu holatda havolani o'ylab
  /// topardi va foydalanuvchi MAVJUD BO'LMAGAN xonani ko'rardi. Endi havola
  /// bo'lmasa — havola bloki umuman ko'rsatilmaydi va halol izoh beriladi.
  Widget _buildSuccessView(
    BuildContext context,
    AppL10n l10n,
    bool isDark,
    String? meetingLink,
  ) {
    final hasLink = meetingLink != null && meetingLink.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.emeraldDarkBg : AppColors.emeraldLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.emerald,
                size: 64,
              ),
            ),
            const Gap(20),
            Text(
              l10n.paymentSuccessTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(10),
            Text(
              hasLink
                  ? l10n.paymentSuccessWithLink
                  : l10n.paymentSuccessNoLink,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            if (hasLink)
              ModernContainer(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.videocam_rounded, color: AppColors.indigo),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        meetingLink,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const Gap(32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l10n.paymentGoToMyConsultations,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/consultation_labels.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation_slot.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_bloc.dart';
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

  // P0-07: `_onPayPressed` OLIB TASHLANDI. Ilgari u
  // `providerTransactionId: 'tx_<provider>_<millis>'` ni CLIENT tomonda
  // to'qib chiqarib `ConfirmPaymentEvent` yuborardi. Webhook endi faqat
  // `service_role` uchun — bu chaqiruv 403 bo'ladi va foydalanuvchiga
  // texnik xato ko'rsatilardi. Bloc/usecase/datasource yo'li O'ZGARMADI:
  // real to'lov provayderi Edge Function orqali ulanganda shu yo'l ishlaydi.

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
                content: Text(errorStateText(context.l10n, state.message, state.code)),
                // O'LCHANGAN: OQ SnackBar matni `crimson` fonida 3.76:1 —
                // AA'dan past. `emergencyStrong`: 6.47:1.
                backgroundColor: AppColors.emergencyStrong,
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
                              // O'LCHANGAN: OQ ikonka `indigo` plashkasida
                              // 4.47:1 — grafik uchun (3:1) o'tadi, lekin
                              // `indigoDark` bilan 6.29:1 va tugma bilan
                              // BIR XIL rang bo'ladi.
                              color:
                                  isDark ? AppColors.indigoDark : AppColors.primary,
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
                              // O'LCHANGAN: TO'LOV SUMMASI — `amberDark` oq
                              // karta ustida 3.19:1. Ton: 7.09 / 10.15.
                              color: AppTone.warning.on(isDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Gap(20),

                // P0-07 — HALOL HOLAT: onlayn to'lov ulanmagan.
                // Ilgari bu yerda "Xavfsiz Escrow / 24 soat oldin 100%
                // qaytarish kafolatlangan" kartasi turardi. Escrow ham,
                // refund ham amalda YO'Q edi — shuning uchun olib tashlandi.
                ModernContainer(
                  backgroundColor: isDark
                      ? AppColors.amber.withValues(alpha: 0.1)
                      : AppColors.amber.withValues(alpha: 0.08),
                  borderColor: isDark
                      ? AppColors.amber.withValues(alpha: 0.3)
                      : AppColors.amber.withValues(alpha: 0.25),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // O'LCHANGAN: xom `amber` o'z 8% tintida 2.02:1
                      // (ikonka uchun 3:1). Ton: 6.67 / 8.56.
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppTone.warning.on(isDark),
                        size: 26,
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.paymentGatewayUnavailableTitle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                // O'LCHANGAN: 13 px matn o'z tintida
                                // 3.00:1 (yorug'). Ton: 6.67 / 8.56.
                                color: AppTone.warning.on(isDark),
                              ),
                            ),
                            const Gap(4),
                            Text(
                              l10n.paymentGatewayUnavailableBody,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                // O'LCHANGAN: 12 px oddiy matn — 3.00:1.
                                // Ton: 6.67 / 8.56.
                                color: AppTone.warning.on(isDark),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
                      // O'LCHANGAN DEFEKT: to'lov usuli rangi XOM ishlatilardi
                      // (`indigo`, `primary`, `accent`) — TANLANGAN holat
                      // signali ham shu rang edi. `Click Up` (`primary`
                      // #0F172A) qorong'i mavzuda karta ustida 1.18:1 berardi,
                      // ya'ni "qaysi usul tanlangan" KO'RINMASDI (1.4.11 —
                      // holat uchun 3:1). Ton: neytral aksent 5.71:1,
                      // `indigo` 2.79 -> 6.25.
                      child: ModernContainer(
                        borderColor: isSelected
                            ? AppTone.forRawAccent(p['color'] as Color)
                                .accent(isDark)
                            : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        backgroundColor: isSelected
                            ? AppTone.forRawAccent(p['color'] as Color)
                                .bg(isDark, alpha: 0.08)
                            : null,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTone.forRawAccent(p['color'] as Color)
                                    .bg(isDark, alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              // O'LCHANGAN: ikonka o'z 15% tintida —
                              // `primary` qorong'ida 1.18:1, `indigo`
                              // qorong'ida 2.79:1. Ton: 14.46 / 6.25.
                              child: Icon(
                                p['icon'] as IconData,
                                color: AppTone.forRawAccent(p['color'] as Color)
                                    .on(isDark),
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
                                      ? AppTone.forRawAccent(
                                              p['color'] as Color)
                                          .accent(isDark)
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
                                          // radio nuqtasi — TANLANGAN holat
                                          // yagona signali, shuning uchun
                                          // `on()` (eng to'yingan) qiymat.
                                          color: AppTone.forRawAccent(
                                                  p['color'] as Color)
                                              .on(isDark),
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

                // P0-07 — To'lov tugmasi O'CHIRILGAN.
                // Sabab: `process_payment_webhook` RPC'si endi faqat
                // `service_role` uchun (migration 20260828). Ilgari bu tugma
                // client tomonda `providerTransactionId` ni O'ZI to'qib
                // chiqarib webhook'ni chaqirardi — ya'ni pul to'lanmagan
                // holda bron `paid`/`confirmed` bo'lardi. Real to'lov
                // provayderi + Edge Function ulangunicha tugma bosilmaydi.
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      // O'LCHANGAN: qorong'ida fon `indigo` + OQ yorliq
                      // 4.47:1 — AA 4.5:1 dan bir oz past. `indigoDark`:
                      // 6.29:1 (mavzuning `elevatedButtonTheme` si bilan bir
                      // xil). Yorug' tomon `primary` 17.85:1 — o'zgarmaydi.
                      backgroundColor:
                          isDark ? AppColors.indigoDark : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.lock_clock_rounded, size: 20),
                    label: Text(
                      l10n.paymentGatewayUnavailableAction,
                      style: const TextStyle(
                        fontSize: 15,
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
              // O'LCHANGAN: 64 px ikonka `emeraldLight` fonida 2.24:1 —
              // eng katta grafik element eng past kontrastda edi.
              // Ton: 6.78 / 8.16.
              child: Icon(
                Icons.check_circle_rounded,
                color: AppTone.success.on(isDark),
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
                    // O'LCHANGAN: 4.47 / 3.27:1. Ton: 6.29 / 7.34.
                    Icon(Icons.videocam_rounded,
                        color: AppTone.accentIndigo.on(isDark)),
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
                  // O'LCHANGAN: OQ yorliq `emerald` fonida 2.54:1.
                  // `emeraldStrong`: 7.68:1.
                  backgroundColor: AppColors.emeraldStrong,
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/consultation_labels.dart';
import 'package:lexhub/core/localization/expert_labels.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation_slot.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_bloc.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_event.dart';
import 'package:lexhub/features/consultations/presentation/bloc/consultation_state.dart';
import 'package:lexhub/features/consultations/presentation/pages/payment_checkout_page.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';

class BookConsultationPage extends StatefulWidget {
  final LegalExpert expert;

  const BookConsultationPage({super.key, required this.expert});

  static Future<void> show(BuildContext context, LegalExpert expert) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<ConsultationBloc>(),
          child: BookConsultationPage(expert: expert),
        ),
      ),
    );
  }

  @override
  State<BookConsultationPage> createState() => _BookConsultationPageState();
}

class _BookConsultationPageState extends State<BookConsultationPage> {
  late DateTime _selectedDate;
  ConsultationSlot? _selectedSlot;
  String _meetingType = 'online';
  final TextEditingController _notesController = TextEditingController();

  final List<DateTime> _dates = List.generate(
    14,
    (index) => DateTime.now().add(Duration(days: index + 1)),
  );

  @override
  void initState() {
    super.initState();
    _selectedDate = _dates.first;
    _loadSlots();
  }

  void _loadSlots() {
    context.read<ConsultationBloc>().add(
          LoadExpertSlotsEvent(
            expertId: widget.expert.id,
            date: _selectedDate,
          ),
        );
  }

  void _onProceedToBooking() {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.bookSelectSlotWarning),
          backgroundColor: AppColors.amberDark,
        ),
      );
      return;
    }

    context.read<ConsultationBloc>().add(
          BookConsultationEvent(
            expertId: widget.expert.id,
            scheduledAt: _selectedSlot!.slotTime,
            meetingType: _meetingType,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
          ),
        );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// §6: TO'QIMA NARX YO'Q.
  ///
  /// Ilgari `widget.expert.consultationFee ?? 150000.0` yozilgan edi — ya'ni
  /// server narx bermasa CLIENT 150 000 so'mni O'YLAB TOPARDI va foydalanuvchi
  /// tugmada shu summani ko'rib "To'lovga o'tish" bosardi. Endi narx avval
  /// tanlangan SLOT'dan (`get_expert_available_slots` qaytargan server
  /// qiymati), keyin advokat profilidan olinadi; ikkisi ham bo'lmasa —
  /// summa KO'RSATILMAYDI ("Kelishuv asosida").
  double? get _effectiveFee {
    final slotPrice = _selectedSlot?.priceAmountUzs;
    if (slotPrice != null && slotPrice > 0) return slotPrice;
    final expertFee = widget.expert.consultationFee;
    if (expertFee != null && expertFee > 0) return expertFee;
    return null;
  }

  /// Narx satri. Davomiylik ham FAQAT server qiymatidan olinadi — ilgari
  /// "45 daqiqa" matnga qotib qolgan edi.
  String _priceText(AppL10n l10n) {
    final fee = _effectiveFee;
    if (fee == null) return l10n.expertFeeNegotiable;
    final amount = fee.toStringAsFixed(0);
    final minutes = _selectedSlot?.durationMinutes ?? 0;
    return minutes > 0
        ? l10n.bookPriceWithDuration(amount, minutes)
        : l10n.bookPriceLine(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.bookTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: BlocConsumer<ConsultationBloc, ConsultationState>(
        listener: (context, state) {
          if (state is BookingInitiatedState) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ConsultationBloc>(),
                  child: PaymentCheckoutPage(
                    checkoutResult: state.checkoutResult,
                  ),
                ),
              ),
            );
          } else if (state is ConsultationErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorStateText(context.l10n, state.message, state.code)),
                backgroundColor: AppColors.crimson,
              ),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expert Summary Header
                ModernContainer(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: isDark ? AppColors.indigo : AppColors.primary,
                        child: Text(
                          // Bo'sh ism `substring(0, 1)` da RangeError bermaydi.
                          expertAvatarInitial(widget.expert),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const Gap(14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expertDisplayName(l10n, widget.expert),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Gap(2),
                            Text(
                              expertSpecializationText(l10n, widget.expert),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            const Gap(4),
                            Text(
                              _priceText(l10n),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.amber : AppColors.amberDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Gap(20),

                // Date Selector
                Text(
                  l10n.bookSelectDate,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(10),
                SizedBox(
                  height: 74,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dates.length,
                    separatorBuilder: (_, __) => const Gap(8),
                    itemBuilder: (context, index) {
                      final date = _dates[index];
                      final isSelected = date.year == _selectedDate.year &&
                          date.month == _selectedDate.month &&
                          date.day == _selectedDate.day;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDate = date;
                            _selectedSlot = null;
                          });
                          _loadSlots();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 65,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? AppColors.indigo : AppColors.primary)
                                : (isDark ? AppColors.cardDark : AppColors.cardLight),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark ? AppColors.indigo : AppColors.primary)
                                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                weekdayShortLabel(l10n, date.weekday),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white70
                                      : (isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight),
                                ),
                              ),
                              const Gap(4),
                              Text(
                                "${date.day}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Gap(22),

                // Time Slots Grid
                Text(
                  l10n.bookAvailableSlots,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(10),

                if (state is ConsultationLoadingState)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state is SlotsLoadedState)
                  _buildSlotsGrid(l10n, state.slots, isDark)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(l10n.bookSlotsLoading),
                  ),

                const Gap(22),

                // Meeting Type Selector
                Text(
                  l10n.bookMeetingTypeTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(10),
                // MUHIM (§16): chip ID'lari (`online`/`phone`/`office`) —
                // `book_consultation(p_meeting_type)` ga ketadigan XOM DB
                // qiymatlari, ular TARJIMA QILINMAYDI.
                Row(
                  children: [
                    _buildMeetingTypeChip(
                        'online', l10n, Icons.videocam_rounded, isDark),
                    const Gap(8),
                    _buildMeetingTypeChip(
                        'phone', l10n, Icons.phone_rounded, isDark),
                    const Gap(8),
                    _buildMeetingTypeChip(
                        'office', l10n, Icons.business_rounded, isDark),
                  ],
                ),

                const Gap(22),

                // Notes input
                Text(
                  l10n.bookNotesTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l10n.bookNotesHint,
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                  ),
                ),

                const Gap(28),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: state is ConsultationLoadingState
                        ? null
                        : _onProceedToBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.indigo : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: Text(
                      _submitLabel(l10n),
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

  /// Tugma yorlig'i: slot tanlanmagan bo'lsa — "Vaqtni tanlang"; tanlangan
  /// bo'lsa summa ko'rsatiladi. Summa YO'Q bo'lsa (server narx bermagan)
  /// tugmada TO'QIMA raqam chiqmaydi, faqat "To'lovga o'tish".
  String _submitLabel(AppL10n l10n) {
    if (_selectedSlot == null) return l10n.bookSelectTime;
    final fee = _effectiveFee;
    return fee == null
        ? l10n.bookProceedToPayment
        : l10n.bookProceedToPaymentAmount(fee.toStringAsFixed(0));
  }

  Widget _buildSlotsGrid(AppL10n l10n, List<ConsultationSlot> slots, bool isDark) {
    if (slots.isEmpty) {
      return ModernContainer(
        padding: const EdgeInsets.all(16),
        child: Text(l10n.bookNoSlots),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isSelected = _selectedSlot?.slotTime == slot.slotTime;
        final timeStr =
            "${slot.slotTime.hour.toString().padLeft(2, '0')}:${slot.slotTime.minute.toString().padLeft(2, '0')}";

        if (!slot.isAvailable) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              timeStr,
              style: TextStyle(
                color: isDark ? Colors.white30 : Colors.black38,
                decoration: TextDecoration.lineThrough,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return InkWell(
          onTap: () {
            setState(() {
              _selectedSlot = slot;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.indigo : AppColors.primary)
                  : (isDark ? AppColors.emerald.withValues(alpha: 0.15) : AppColors.emerald.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? (isDark ? AppColors.indigo : AppColors.primary)
                    : AppColors.emerald.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              timeStr,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.emerald : AppColors.emeraldDark),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMeetingTypeChip(
      String type, AppL10n l10n, IconData icon, bool isDark) {
    final isSelected = _meetingType == type;
    final label = consultationMeetingTypeLabel(l10n, type);
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _meetingType = type;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.indigo : AppColors.primary).withValues(alpha: 0.15)
                : (isDark ? AppColors.cardDark : AppColors.cardLight),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppColors.indigo : AppColors.primary)
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? (isDark ? AppColors.indigo : AppColors.primary)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
              const Gap(4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? AppColors.indigo : AppColors.primary)
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

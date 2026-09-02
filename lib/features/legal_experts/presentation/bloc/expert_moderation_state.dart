import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application.dart';

abstract class ExpertModerationState extends Equatable {
  const ExpertModerationState();

  @override
  List<Object?> get props => [];
}

class ExpertModerationInitial extends ExpertModerationState {
  const ExpertModerationInitial();
}

class ExpertModerationLoading extends ExpertModerationState {
  const ExpertModerationLoading();
}

class ExpertModerationLoaded extends ExpertModerationState {
  final List<ExpertApplication> applications;

  const ExpertModerationLoaded(this.applications);

  @override
  List<Object?> get props => [applications];
}

/// RPC ketdi, javob KELMADI. Ro'yxat ekranda QOLADI — faqat `targetUserId`
/// kartasi bloklanadi. Butun ekranni spinnerga almashtirish moderatorning
/// joyini yo'qotardi va ikkinchi marta bosish xavfini oshirardi.
class ExpertModerationInProgress extends ExpertModerationState {
  final List<ExpertApplication> applications;
  final String targetUserId;

  const ExpertModerationInProgress({
    required this.applications,
    required this.targetUserId,
  });

  @override
  List<Object?> get props => [applications, targetUserId];
}

/// RPC MUVAFFAQIYATLI bajarildi.
///
/// `listRefreshed == false` — RPC o'tdi, LEKIN ro'yxatni qayta yuklash
/// yiqildi. Bu holat YASHIRILMAYDI: UI boshqa xabar ko'rsatadi, aks holda
/// moderator ekrandagi eskirgan ro'yxatni haqiqat deb qabul qilardi (§20).
class ExpertModerationActionDone extends ExpertModerationState {
  final List<ExpertApplication> applications;
  final String fullName;
  final bool approved;
  final bool listRefreshed;

  /// RAD ETISH ADVOKAT MAQOMINI HAM BEKOR QILDIMI.
  ///
  /// `verify_expert_application(p_approve => FALSE)` tasdiqlangan advokatni
  /// `citizen` ga qaytarganda javobda `role_reverted: true` keladi. Bu FAQAT
  /// SERVER aytgan haqiqat — klient buni taxmin qilmaydi va hisoblamaydi.
  ///
  /// RUNTIME'DA O'LCHANGAN (2026-08-29): rad etish javobi
  /// `{"role_reverted": true, "previous_role": "verified_expert"}`.
  final bool roleReverted;

  const ExpertModerationActionDone({
    required this.applications,
    required this.fullName,
    required this.approved,
    required this.listRefreshed,
    this.roleReverted = false,
  });

  @override
  List<Object?> get props =>
      [applications, fullName, approved, listRefreshed, roleReverted];
}

/// RPC YIQILDI (huquq yo'q / tarmoq / server). Ro'yxat ekranda qoladi,
/// xato SnackBar bilan beriladi — moderator qayta urinishi mumkin.
class ExpertModerationActionFailed extends ExpertModerationState {
  final List<ExpertApplication> applications;
  final String message;
  final FailureCode? code;

  const ExpertModerationActionFailed({
    required this.applications,
    required this.message,
    this.code,
  });

  @override
  List<Object?> get props => [applications, message, code];
}

class ExpertModerationError extends ExpertModerationState {
  final String message;
  final FailureCode? code;

  const ExpertModerationError(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

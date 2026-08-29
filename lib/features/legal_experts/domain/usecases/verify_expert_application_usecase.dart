import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/legal_experts_repository.dart';

class VerifyExpertApplicationParams extends Equatable {
  /// `expert_profiles.user_id` — `verify_expert_application()` AYNAN shuni
  /// kutadi. `expert_profiles.id` yuborilsa RPC profilni topmaydi.
  final String userId;

  /// `true` — tasdiqlash (`role = 'verified_expert'`, `is_verified = TRUE`,
  /// `verified_at = now()`); `false` — rad etish (`verified_at = NULL`).
  final bool approve;

  const VerifyExpertApplicationParams({
    required this.userId,
    required this.approve,
  });

  @override
  List<Object?> get props => [userId, approve];
}

/// ARIZANI TASDIQLASH / RAD ETISH.
///
/// XAVFSIZLIK CHEGARASI SERVERDA: RPC `is_admin_or_moderator()` bilan
/// himoyalangan. Bu usecase huquqni TEKSHIRMAYDI va tekshirmasligi ham kerak —
/// klient tomonidagi tekshiruv ishonch manbasi bo'lib qolsa, APK'ni
/// o'zgartirgan har kim advokat tasdiqlab qo'yardi.
class VerifyExpertApplicationUseCase
    implements UseCase<Map<String, dynamic>, VerifyExpertApplicationParams> {
  final LegalExpertsRepository repository;

  VerifyExpertApplicationUseCase(this.repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(
      VerifyExpertApplicationParams params) async {
    return await repository.verifyExpertApplication(
      userId: params.userId,
      approve: params.approve,
    );
  }
}

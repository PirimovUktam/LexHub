import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/legal_experts_repository.dart';

/// TASDIQLASH KUTAYOTGAN ARIZALAR — moderatsiya ekrani uchun.
///
/// Parametr YO'Q: filtr (`verified_at IS NULL`) va ko'rish huquqi SERVER
/// tomonda (RLS + so'rov) belgilanadi. Klientdan "kimning arizalarini
/// ko'rsatish" parametrini olish IDOR yuzasini ochardi.
class GetPendingApplicationsUseCase
    implements UseCase<List<ExpertApplication>, NoParams> {
  final LegalExpertsRepository repository;

  GetPendingApplicationsUseCase(this.repository);

  @override
  Future<Either<Failure, List<ExpertApplication>>> call(
      NoParams params) async {
    return await repository.getPendingApplications();
  }
}

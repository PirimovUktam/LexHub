import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/get_pending_applications_usecase.dart';
import 'package:lexhub/features/legal_experts/domain/usecases/verify_expert_application_usecase.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/expert_moderation_event.dart';
import 'package:lexhub/features/legal_experts/presentation/bloc/expert_moderation_state.dart';

/// ARIZA MODERATSIYASI — `LegalExpertsBloc` dan ALOHIDA.
///
/// Ro'yxat holati (filtr, qidiruv, katalog) bilan moderatsiya holati
/// (tasdiqlash jarayoni, natija) bitta bloc'ga qo'shilsa God Class va
/// tushunarsiz state machine chiqardi (§5): "yuklanmoqda" ikki xil ma'noga
/// ega bo'lib qolardi.
///
/// XAVFSIZLIK: bu bloc huquqni TEKSHIRMAYDI. Chegara serverda —
/// `verify_expert_application()` ichidagi `is_admin_or_moderator()` va
/// `expert_profiles` RLS. Klient tomonidagi rol tekshiruvi UI'ni
/// tartibga solish uchun, ishonch manbasi EMAS.
class ExpertModerationBloc
    extends Bloc<ExpertModerationEvent, ExpertModerationState> {
  final GetPendingApplicationsUseCase getPendingApplicationsUseCase;
  final VerifyExpertApplicationUseCase verifyExpertApplicationUseCase;

  ExpertModerationBloc({
    required this.getPendingApplicationsUseCase,
    required this.verifyExpertApplicationUseCase,
  }) : super(const ExpertModerationInitial()) {
    on<LoadPendingApplicationsEvent>(_onLoadPending);
    on<ModerateApplicationEvent>(_onModerate);
  }

  /// Ekranda hozir turgan ro'yxat. Xato yoki yuklanish holatida BO'SH —
  /// to'qilgan ro'yxat qaytarilmaydi.
  List<ExpertApplication> get _currentApplications {
    final current = state;
    if (current is ExpertModerationLoaded) return current.applications;
    if (current is ExpertModerationInProgress) return current.applications;
    if (current is ExpertModerationActionDone) return current.applications;
    if (current is ExpertModerationActionFailed) return current.applications;
    return const <ExpertApplication>[];
  }

  Future<void> _onLoadPending(
    LoadPendingApplicationsEvent event,
    Emitter<ExpertModerationState> emit,
  ) async {
    emit(const ExpertModerationLoading());
    final result = await getPendingApplicationsUseCase(NoParams());
    result.fold(
      (failure) =>
          emit(ExpertModerationError(failure.message, code: failure.code)),
      (applications) => emit(ExpertModerationLoaded(applications)),
    );
  }

  Future<void> _onModerate(
    ModerateApplicationEvent event,
    Emitter<ExpertModerationState> emit,
  ) async {
    final before = _currentApplications;

    // Ism SnackBar matni uchun kerak. Ro'yxatda topilmasa BO'SH qoladi —
    // UI "noma'lum arizachi" yorlig'ini ko'rsatadi. To'qilgan ism YO'Q (§20).
    final target = before.where((a) => a.userId == event.userId).toList();
    final fullName = target.isEmpty ? '' : target.first.fullName;

    emit(ExpertModerationInProgress(
      applications: before,
      targetUserId: event.userId,
    ));

    final result = await verifyExpertApplicationUseCase(
      VerifyExpertApplicationParams(
        userId: event.userId,
        approve: event.approve,
      ),
    );

    // `fold` ichida `await` qilmaslik uchun xato AVVAL ajratiladi:
    // qayta yuklash asinxron va u faqat RPC o'tgan yo'lda kerak.
    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      emit(ExpertModerationActionFailed(
        applications: before,
        message: failure.message,
        code: failure.code,
      ));
      return;
    }

    // SERVER AYTGAN OQIBAT. Tasdiqlangan advokat rad etilsa RPC uni `citizen`
    // ga qaytaradi va buni `role_reverted` da e'lon qiladi. Klient bu qarorni
    // O'ZI HISOBLAMAYDI — faqat serverdan kelganini uzatadi (§14: xavfsizlik
    // haqiqati manbasi server).
    final roleReverted =
        result.fold<bool>((_) => false, (data) => data['role_reverted'] == true);

    // RPC O'TDI. Endi SERVER holatini qayta o'qiymiz — mahalliy taxmin
    // ishonch manbasi emas.
    final refreshed = await getPendingApplicationsUseCase(NoParams());
    refreshed.fold(
      (_) {
        // Qayta yuklash yiqildi. RPC O'TGANI ANIQ, ya'ni server IKKALA yo'lda
        // ham TERMINAL holat yozdi: tasdiqlashda `verified_at`, rad etishda
        // `rejected_at` (`20260829010000_expert_rejection_and_revocation.sql`).
        // Ikkisi ham kutayotganlar filtridan (`verified_at IS NULL AND
        // rejected_at IS NULL`) CHIQARADI, shuning uchun qator mahalliy olib
        // tashlanadi.
        //
        // RUNTIME'DA O'LCHANGAN (2026-08-29): rad etishdan keyin kutayotgan
        // arizalar 1 -> 0. Ilgari bu shox rad etilgan arizani ATAYLAB
        // qoldirardi, chunki o'sha paytda bazada "rad etilgan" holati YO'Q
        // edi — endi bor, shuning uchun qoldirish YOLG'ON bo'lardi.
        //
        // Ro'yxat baribir ESKIRGAN deb belgilanadi: mahalliy tuzatish qayta
        // o'qish O'RNINI BOSMAYDI (`listRefreshed: false` -> SnackBar aytadi).
        final patched =
            before.where((a) => a.userId != event.userId).toList();
        emit(ExpertModerationActionDone(
          applications: patched,
          fullName: fullName,
          approved: event.approve,
          listRefreshed: false,
          roleReverted: roleReverted,
        ));
      },
      (applications) => emit(ExpertModerationActionDone(
        applications: applications,
        fullName: fullName,
        approved: event.approve,
        listRefreshed: true,
        roleReverted: roleReverted,
      )),
    );
  }
}

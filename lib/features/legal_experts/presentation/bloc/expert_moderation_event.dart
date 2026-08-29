import 'package:equatable/equatable.dart';

abstract class ExpertModerationEvent extends Equatable {
  const ExpertModerationEvent();

  @override
  List<Object?> get props => [];
}

/// TASDIQLASH KUTAYOTGAN arizalarni yuklash.
///
/// Parametr YO'Q: "kimning arizalari" ni klient tanlamaydi (IDOR yuzasi).
/// Ko'rish huquqini `expert_profiles` RLS belgilaydi.
class LoadPendingApplicationsEvent extends ExpertModerationEvent {
  const LoadPendingApplicationsEvent();
}

/// Arizani TASDIQLASH (`approve: true`) yoki RAD ETISH (`approve: false`).
///
/// `userId` — `expert_profiles.user_id`, `expert_profiles.id` EMAS: RPC
/// `p_target_user_id` sifatida aynan shuni kutadi.
class ModerateApplicationEvent extends ExpertModerationEvent {
  final String userId;
  final bool approve;

  const ModerateApplicationEvent({
    required this.userId,
    required this.approve,
  });

  @override
  List<Object?> get props => [userId, approve];
}

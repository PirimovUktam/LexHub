import 'package:flutter/material.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/features/legal_experts/presentation/pages/advocate_profile_page.dart';

/// Existing directory entry point. The profile reloads its authoritative
/// aggregate instead of treating an older directory card as profile data.
class ExpertProfileModal extends StatelessWidget {
  final LegalExpert expert;

  const ExpertProfileModal({super.key, required this.expert});

  static void show(BuildContext context, LegalExpert expert) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => AdvocateProfilePage(expertId: expert.id, bookingExpert: expert),
    ));
  }

  @override
  Widget build(BuildContext context) =>
      AdvocateProfilePage(expertId: expert.id, bookingExpert: expert);
}

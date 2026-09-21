import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_event.dart';
import 'package:lexhub/features/auth/presentation/pages/edit_profile_page.dart';

class ProfileDetailsCard extends StatelessWidget {
  const ProfileDetailsCard({super.key, required this.profile});
  final UserProfileEntity profile;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final date = profile.dateOfBirth;
    final details = <String, String?>{
      l.profileFirstName: profile.firstName,
      l.profileLastName: profile.lastName,
      l.profilePhone: profile.phone,
      l.profileEmail: profile.email,
      l.profileBirthDate:
          date == null ? null : DateFormat.yMd(l.localeName).format(date),
      l.profileGender: switch (profile.gender) {
        ProfileGender.male => l.profileMale,
        ProfileGender.female => l.profileFemale,
        null => null,
      },
      l.profileAddress: profile.address,
      l.profileOccupation: profile.occupation,
      l.profileBio: profile.bio,
    };
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.profileDetailsTitle,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
            builder: (context, constraints) => Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.lg,
                  children: details.entries
                      .map((entry) => SizedBox(
                            width: constraints.maxWidth >= 560
                                ? (constraints.maxWidth - AppSpacing.md) / 2
                                : constraints.maxWidth,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.key,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge),
                                  const SizedBox(height: AppSpacing.xs),
                                  SelectableText(entry.value?.isNotEmpty == true
                                      ? entry.value ?? ''
                                      : l.profileNotProvided),
                                ]),
                          ))
                      .toList(),
                )),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: Text(l.profileEditDetails),
            onPressed: () async {
              final auth = context.read<AuthBloc>();
              final saved = await Navigator.of(context).push<UserProfileEntity>(
                  MaterialPageRoute(
                      builder: (_) => EditProfilePage(profile: profile)));
              if (saved != null && !auth.isClosed) {
                auth.add(LoadUserProfileEvent(saved.id));
              }
            }),
      ]),
    ));
  }
}

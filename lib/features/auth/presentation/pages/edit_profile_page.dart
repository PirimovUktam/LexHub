import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/theme/app_page_body.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/features/auth/data/repositories/profile_avatar_repository.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';
import 'package:lexhub/features/auth/presentation/bloc/profile_editor_cubit.dart';
import 'package:lexhub/features/auth/presentation/widgets/private_profile_avatar.dart';
import 'package:lexhub/features/auth/presentation/widgets/profile_image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage(
      {super.key, required this.profile, this.cubit, this.pickImage});
  final UserProfileEntity profile;
  final ProfileEditorCubit? cubit;
  final Future<XFile?> Function()? pickImage;
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final ProfileEditorCubit _cubit;
  late final Map<String, TextEditingController> _fields;
  DateTime? _birthDate;
  ProfileGender? _gender;
  Uint8List? _photo;
  bool _picking = false;
  bool _photoError = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _cubit = widget.cubit ?? ProfileEditorCubit(sl(), sl());
    _fields = {
      'firstName': TextEditingController(text: p.firstName),
      'lastName': TextEditingController(text: p.lastName),
      'phone': TextEditingController(text: p.phone),
      'address': TextEditingController(text: p.address),
      'occupation': TextEditingController(text: p.occupation),
      'bio': TextEditingController(text: p.bio),
    };
    _birthDate = p.dateOfBirth;
    _gender = p.gender;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    if (widget.cubit == null) _cubit.close();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _photoError = false;
    });
    try {
      final picked = await (widget.pickImage?.call() ?? pickProfileImage());
      if (picked == null) return;
      late final Uint8List bytes;
      try {
        if (await picked.length() > ProfileAvatarRepository.maxBytes) {
          throw const FormatException();
        }
        bytes = await picked.readAsBytes();
      } finally {
        releaseProfileImage(picked);
      }
      if (ProfileAvatarRepository.imageExtension(bytes) == null) {
        throw const FormatException();
      }
      // ImageDescriptor.width/height throw on web for encoded images. Decode a
      // bounded frame using the codec API supported on all target platforms.
      final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 1024, targetHeight: 1024, allowUpscaling: false);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) setState(() => _photoError = true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
        context: context,
        initialDate: _birthDate ?? DateTime(now.year, now.month, now.day),
        firstDate: DateTime(1),
        lastDate: now);
    if (mounted && selected != null) setState(() => _birthDate = selected);
  }

  String? _value(String key) {
    final value = _fields[key]?.text.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  void _save() {
    if (_form.currentState?.validate() != true) return;
    _cubit.save(
        widget.profile.copyWith(
            firstName: _value('firstName'),
            lastName: _value('lastName'),
            phone: _value('phone'),
            address: _value('address'),
            occupation: _value('occupation'),
            bio: _value('bio'),
            dateOfBirth: _birthDate,
            gender: _gender),
        image: _photo);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocConsumer<ProfileEditorCubit, ProfileEditorState>(
      bloc: _cubit,
      listener: (context, state) {
        final saved = state.saved;
        if (saved != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.cleanupFailed
                  ? l.profileCleanupWarning
                  : l.profileSaved)));
          Navigator.of(context).pop(saved);
        }
      },
      builder: (context, state) => PopScope(
          canPop: !state.saving,
          child: Scaffold(
            appBar: AppBar(title: Text(l.profileEditDetails)),
            body: AppPageBody(
                maxWidth: 720,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                      key: _form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                                child: PrivateProfileAvatar(
                                    owner: widget.profile.id,
                                    name: widget.profile.fullName,
                                    path: widget.profile.avatarPath,
                                    preview: _photo)),
                            TextButton.icon(
                                onPressed:
                                    state.saving || _picking ? null : _pick,
                                icon: _picking
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator())
                                    : const Icon(Icons.add_a_photo_outlined),
                                label: Text(l.profileChoosePhoto)),
                            Text(l.profilePhotoHint,
                                textAlign: TextAlign.center),
                            if (_photoError)
                              Text(l.profilePhotoInvalid,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                            const SizedBox(height: AppSpacing.lg),
                            LayoutBuilder(builder: (context, constraints) {
                              final width = constraints.maxWidth >= 560
                                  ? (constraints.maxWidth - AppSpacing.md) / 2
                                  : constraints.maxWidth;
                              Widget field(String key, String label, int limit,
                                      {TextInputType? keyboard,
                                      int lines = 1}) =>
                                  SizedBox(
                                      width: width,
                                      child: TextFormField(
                                          key: ValueKey('profile_$key'),
                                          controller: _fields[key],
                                          enabled: !state.saving,
                                          maxLength: limit,
                                          minLines: lines,
                                          maxLines: lines,
                                          keyboardType: keyboard,
                                          decoration: InputDecoration(
                                              labelText: label,
                                              helperText: key == 'phone'
                                                  ? l.profilePhoneHint
                                                  : null,
                                              helperMaxLines: 2),
                                          validator: (value) {
                                            if ((value?.runes.length ?? 0) >
                                                limit) {
                                              return l.profileTooLong;
                                            }
                                            if (key == 'phone' &&
                                                (value?.trim().isNotEmpty ??
                                                    false) &&
                                                !RegExp(r'^\+[1-9][0-9]{7,14}$')
                                                    .hasMatch(
                                                        value?.trim() ?? '')) {
                                              return l.profileInvalidPhone;
                                            }
                                            return null;
                                          }));
                              return Wrap(
                                  spacing: AppSpacing.md,
                                  runSpacing: AppSpacing.md,
                                  children: [
                                    field('firstName', l.profileFirstName, 64),
                                    field('lastName', l.profileLastName, 64),
                                    field('phone', l.profilePhone, 16,
                                        keyboard: TextInputType.phone),
                                    SizedBox(
                                        width: width,
                                        child: TextFormField(
                                            initialValue:
                                                widget.profile.email ?? '',
                                            readOnly: true,
                                            decoration: InputDecoration(
                                                labelText: l.profileEmail,
                                                helperText: l.profileEmailHint,
                                                helperMaxLines: 2))),
                                    SizedBox(
                                        width: width,
                                        child: InputDecorator(
                                            decoration: InputDecoration(
                                                labelText: l.profileBirthDate),
                                            child: Row(children: [
                                              Expanded(
                                                  child: TextButton(
                                                      key: const ValueKey(
                                                          'profile_birth_date'),
                                                      onPressed: state.saving
                                                          ? null
                                                          : _chooseDate,
                                                      child: Text(_birthDate ==
                                                              null
                                                          ? l.profileNotProvided
                                                          : DateFormat.yMd(
                                                                  l.localeName)
                                                              .format(_birthDate ??
                                                                  DateTime
                                                                      .now())))),
                                              if (_birthDate != null)
                                                IconButton(
                                                    tooltip: l.profileClearDate,
                                                    onPressed: state.saving
                                                        ? null
                                                        : () => setState(() =>
                                                            _birthDate = null),
                                                    icon:
                                                        const Icon(Icons.clear))
                                            ]))),
                                    SizedBox(
                                        width: width,
                                        child: DropdownButtonFormField<
                                                ProfileGender>(
                                            key: const ValueKey(
                                                'profile_gender'),
                                            initialValue: _gender,
                                            isExpanded: true,
                                            decoration: InputDecoration(
                                                labelText: l.profileGender),
                                            items: [
                                              DropdownMenuItem(
                                                  value: null,
                                                  child: Text(
                                                      l.profileNotProvided)),
                                              DropdownMenuItem(
                                                  value: ProfileGender.male,
                                                  child: Text(l.profileMale)),
                                              DropdownMenuItem(
                                                  value: ProfileGender.female,
                                                  child: Text(l.profileFemale))
                                            ],
                                            onChanged: state.saving
                                                ? null
                                                : (value) => setState(
                                                    () => _gender = value))),
                                    field('address', l.profileAddress, 500,
                                        lines: 2),
                                    field(
                                        'occupation', l.profileOccupation, 128),
                                    field('bio', l.profileBio, 300, lines: 4),
                                  ]);
                            }),
                            if (state.error != null)
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.md),
                                  child: Text(
                                      failureMessageFor(l,
                                          state.error ?? FailureCode.unknown),
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                            const SizedBox(height: AppSpacing.lg),
                            FilledButton.icon(
                                key: const ValueKey('profile_save'),
                                onPressed:
                                    state.saving || _picking ? null : _save,
                                icon: state.saving
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator())
                                    : const Icon(Icons.check),
                                label: Text(l.profileSave)),
                            TextButton(
                                onPressed: state.saving
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: Text(l.profileCancel)),
                          ])),
                )),
          )),
    );
  }
}

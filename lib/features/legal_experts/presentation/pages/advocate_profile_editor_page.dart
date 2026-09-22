import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/app_page_body.dart';
import 'package:lexhub/features/auth/data/repositories/profile_avatar_repository.dart';
import 'package:lexhub/features/auth/presentation/widgets/profile_image_picker.dart';
import 'package:lexhub/features/legal_experts/domain/entities/advocate_profile.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/advocate_profile_repository.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/advocate_avatar.dart';

class AdvocateProfileEditorPage extends StatefulWidget {
  const AdvocateProfileEditorPage({
    super.key,
    required this.repository,
    this.profile,
    this.pickImage,
  });
  final AdvocateProfileRepository repository;
  final AdvocateProfile? profile;
  final Future<XFile?> Function()? pickImage;

  @override
  State<AdvocateProfileEditorPage> createState() =>
      _AdvocateProfileEditorPageState();
}

class _AdvocateProfileEditorPageState extends State<AdvocateProfileEditorPage> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late bool _published;
  late bool _accepting;
  String? _avatarPath;
  Uint8List? _photo;
  String? _contentType;
  bool _saving = false;
  bool _picking = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _fields = {
      'firstName': TextEditingController(text: p?.firstName),
      'lastName': TextEditingController(text: p?.lastName),
      'experienceYears': TextEditingController(
          text: p == null ? '' : p.experienceYears.toString()),
      'workplace': TextEditingController(text: p?.workplace),
      'bio': TextEditingController(text: p?.bio),
      'address': TextEditingController(text: p?.address),
      'publicPhone': TextEditingController(text: p?.publicPhone),
      'publicEmail': TextEditingController(text: p?.publicEmail),
      'specializations':
          TextEditingController(text: p?.specializations.join(', ')),
      'languages': TextEditingController(text: p?.languages.join(', ')),
    };
    _published = p?.isPublished ?? false;
    _accepting = p?.acceptingClients ?? false;
    _avatarPath = p?.avatarPath;
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String _value(String name) => _fields[name]?.text.trim() ?? '';
  List<String> _list(String name) => _value(name)
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final file = await (widget.pickImage?.call() ?? pickProfileImage());
      if (file == null) return;
      try {
        if (await file.length() > ProfileAvatarRepository.maxBytes) {
          throw const FormatException();
        }
        final bytes = await file.readAsBytes();
        final extension = ProfileAvatarRepository.imageExtension(bytes);
        if (extension == null) throw const FormatException();
        if (mounted) {
          setState(() {
            _photo = bytes;
            _contentType =
                extension == 'jpg' ? 'image/jpeg' : 'image/$extension';
            _failure = null;
          });
        }
      } finally {
        releaseProfileImage(file);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _failure = const ValidationFailure(message: ''));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _form.currentState?.validate() != true) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final photo = _photo;
      final contentType = _contentType;
      if (photo != null && contentType != null) {
        final upload = await widget.repository.uploadAvatar(photo, contentType);
        upload.fold((failure) => _failure = failure, (path) {
          _avatarPath = path;
          _photo = null;
        });
        if (_failure != null) return;
      }
      final result = await widget.repository.saveProfile(AdvocateProfileInput(
        firstName: _value('firstName'),
        lastName: _value('lastName'),
        avatarPath: _avatarPath,
        experienceYears: int.tryParse(_value('experienceYears')) ?? 0,
        workplace: _value('workplace'),
        bio: _value('bio'),
        address: _value('address'),
        publicPhone: _value('publicPhone'),
        publicEmail: _value('publicEmail'),
        specializations: _list('specializations'),
        languages: _list('languages'),
        isPublished: _published,
        acceptingClients: _accepting,
      ));
      if (!mounted) return;
      result.fold((failure) => _failure = failure,
          (saved) => Navigator.pop(context, saved));
    } catch (_) {
      _failure = const ServerFailure(message: '');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final failure = _failure;
    Widget field(String name, String label,
            {int limit = 200,
            bool required = false,
            int lines = 1,
            TextInputType? keyboard,
            String? hint}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: TextFormField(
            key: ValueKey('advocate_profile_$name'),
            controller: _fields[name],
            enabled: !_saving,
            maxLength: limit,
            minLines: lines,
            maxLines: lines,
            keyboardType: keyboard,
            decoration: InputDecoration(labelText: label, helperText: hint),
            validator: (raw) {
              final value = raw?.trim() ?? '';
              if (required && value.isEmpty) return l.advocateRequired;
              if (name == 'specializations' || name == 'languages') {
                final entries = value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                if (entries.length > 12 || entries.any((s) => s.length > 80)) {
                  return l.advocateInvalid;
                }
              }
              if (name == 'experienceYears' &&
                  (int.tryParse(value) == null ||
                      (int.tryParse(value) ?? -1) < 0 ||
                      (int.tryParse(value) ?? 81) > 80)) {
                return l.advocateInvalid;
              }
              if (name == 'publicPhone' &&
                  value.isNotEmpty &&
                  !RegExp(r'^\+[0-9]{8,15}$').hasMatch(value)) {
                return l.profileInvalidPhone;
              }
              if (name == 'publicEmail' &&
                  value.isNotEmpty &&
                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                return l.advocateInvalid;
              }
              return null;
            },
          ),
        );
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(l.advocateMyProfile)),
        body: AppPageBody(
          maxWidth: AppLayout.readingWidth,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.advocateCreateHint),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: AdvocateAvatar(
                        repository: widget.repository,
                        path: _avatarPath,
                        preview: _photo),
                  ),
                  TextButton.icon(
                    onPressed: _saving || _picking ? null : _pick,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(l.profileChoosePhoto),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  field('firstName', l.profileFirstName,
                      limit: 64, required: true),
                  field('lastName', l.profileLastName,
                      limit: 64, required: true),
                  field('experienceYears', l.expertMetricExperience,
                      limit: 2, required: true, keyboard: TextInputType.number),
                  field('specializations', l.advocateSpecializations,
                      limit: 500, hint: l.advocateListHint),
                  field('languages', l.advocateLanguages,
                      limit: 300, hint: l.advocateListHint),
                  field('workplace', l.advocateWorkplace),
                  field('address', l.profileAddress, limit: 500),
                  field('bio', l.profileBio, limit: 3000, lines: 5),
                  Text(l.advocatePublicContactHint),
                  const SizedBox(height: AppSpacing.md),
                  field('publicPhone', l.advocatePublicPhone,
                      limit: 16, keyboard: TextInputType.phone),
                  field('publicEmail', l.advocatePublicEmail,
                      limit: 254, keyboard: TextInputType.emailAddress),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.advocateAccepting),
                    subtitle: Text(l.advocateAvailabilityHint),
                    value: _accepting,
                    onChanged:
                        _saving ? null : (v) => setState(() => _accepting = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.advocatePublish),
                    subtitle: Text(l.advocatePublishHint),
                    value: _published,
                    onChanged:
                        _saving ? null : (v) => setState(() => _published = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(l.advocateVerificationHint),
                  if (failure != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(failureMessageFor(l, failure.code),
                        key: const ValueKey('advocate_profile_error'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    key: const ValueKey('advocate_profile_save'),
                    onPressed: _saving || _picking ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: AppIconSize.sm,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.profileSave),
                  ),
                  const SizedBox(height: AppSpacing.bottomSafe),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

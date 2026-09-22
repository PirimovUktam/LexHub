import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/features/auth/data/repositories/profile_avatar_repository.dart';
import 'package:lexhub/features/auth/presentation/widgets/profile_image_picker.dart';
import 'package:lexhub/features/legal_experts/domain/entities/advocate_profile.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/advocate_profile_repository.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/advocate_form_dialog.dart';

Future<Failure?> advocateFailure<T>(Future<Either<Failure, T>> future) async =>
    (await future).fold((f) => f, (_) => null);

Map<String, String> advocateDeliveryLabels(BuildContext context) => {
      'online': context.l10n.advocateOnline,
      'offline': context.l10n.advocateOffice,
      'written': context.l10n.advocateWritten,
    };

Map<String, String> advocateWeekdays(BuildContext context) => {
      '1': context.l10n.advocateMonday,
      '2': context.l10n.advocateTuesday,
      '3': context.l10n.advocateWednesday,
      '4': context.l10n.advocateThursday,
      '5': context.l10n.advocateFriday,
      '6': context.l10n.advocateSaturday,
      '7': context.l10n.advocateSunday,
    };

/// These editors only assemble validated input. Authorization, ownership,
/// publication and verification remain enforced by the repository/backend.
class AdvocateProfileActions {
  AdvocateProfileActions(this.context, this.repository, this.profile);
  final BuildContext context;
  final AdvocateProfileRepository repository;
  final AdvocateProfile profile;

  Future<bool> service([AdvocateService? value]) {
    final l = context.l10n;
    return AdvocateFormDialog.show(context,
        title: l.advocateServices,
        fields: [
          AdvocateFormField('title', l.advocateServiceTitle,
              initial: value?.title ?? '', required: true, maxLength: 120),
          AdvocateFormField('description', l.advocateDescription,
              initial: value?.description ?? '', maxLength: 2000, lines: 3),
          AdvocateFormField('price', l.advocatePrice,
              initial: value?.priceUzs?.toString() ?? '',
              keyboard: TextInputType.number, validate: (v) {
            if (v.isEmpty) return true;
            final n = double.tryParse(v);
            return n != null && n.isFinite && n >= 0 && n <= 1000000000;
          }),
          AdvocateFormField('duration', l.advocateDuration,
              initial: value?.durationMinutes?.toString() ?? '',
              keyboard: TextInputType.number,
              validate: (v) =>
                  v.isEmpty ||
                  ((int.tryParse(v) ?? 0) >= 5 &&
                      (int.tryParse(v) ?? 481) <= 480)),
          AdvocateFormField('delivery', l.advocateDelivery,
              initial: value?.deliveryMode ?? 'online',
              required: true,
              options: advocateDeliveryLabels(context)),
          AdvocateFormField('active', l.advocateActive,
              initial: value?.isActive == false ? 'false' : 'true',
              required: true,
              options: {'true': l.advocateActive, 'false': l.advocateInactive}),
        ],
        onSave: (v) => advocateFailure(repository.saveService(
            profile.id,
            AdvocateService(
                id: value?.id ?? '',
                title: v['title'] ?? '',
                description: v['description'] ?? '',
                priceUzs: double.tryParse(v['price'] ?? ''),
                durationMinutes: int.tryParse(v['duration'] ?? ''),
                deliveryMode: v['delivery'] ?? 'online',
                isActive: v['active'] == 'true',
                sortOrder: value?.sortOrder ?? profile.services.length))));
  }

  static DateTime? _date(String value) {
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(value);
    } catch (_) {
      return null;
    }
  }

  Future<bool> experience([AdvocateExperience? value]) {
    final l = context.l10n;
    final format = DateFormat('yyyy-MM-dd');
    return AdvocateFormDialog.show(context,
        title: l.advocateExperience,
        fields: [
          AdvocateFormField('organization', l.advocateOrganization,
              initial: value?.organization ?? '', required: true),
          AdvocateFormField('position', l.advocatePosition,
              initial: value?.position ?? '', required: true, maxLength: 120),
          AdvocateFormField('start', l.advocateStartDate,
              initial: value == null ? '' : format.format(value.startDate),
              required: true,
              maxLength: 10,
              validate: (v) => _date(v) != null),
          AdvocateFormField('end', l.advocateEndDate,
              initial: switch (value?.endDate) {
                final DateTime date => format.format(date),
                _ => '',
              },
              maxLength: 10,
              validate: (v) => v.isEmpty || _date(v) != null),
          AdvocateFormField('description', l.advocateDescription,
              initial: value?.description ?? '', maxLength: 2000, lines: 3),
        ], onSave: (v) async {
      final start = _date(v['start'] ?? '');
      final end = _date(v['end'] ?? '');
      if (start == null || (end != null && end.isBefore(start))) {
        return const ValidationFailure(message: '');
      }
      return advocateFailure(repository.saveExperience(
          profile.id,
          AdvocateExperience(
              id: value?.id ?? '',
              organization: v['organization'] ?? '',
              position: v['position'] ?? '',
              startDate: start,
              endDate: end,
              description: v['description'] ?? '')));
    });
  }

  Future<bool> education([AdvocateEducation? value]) {
    final l = context.l10n;
    bool validYear(String v) =>
        (int.tryParse(v) ?? 0) >= 1900 && (int.tryParse(v) ?? 2200) <= 2100;
    return AdvocateFormDialog.show(context,
        title: l.advocateEducation,
        fields: [
          AdvocateFormField('institution', l.advocateInstitution,
              initial: value?.institution ?? '', required: true),
          AdvocateFormField('qualification', l.advocateQualification,
              initial: value?.qualification ?? '', required: true),
          AdvocateFormField('start', l.advocateStartYear,
              initial: value?.startYear.toString() ?? '',
              required: true,
              maxLength: 4,
              keyboard: TextInputType.number,
              validate: validYear),
          AdvocateFormField('end', l.advocateEndYear,
              initial: value?.endYear?.toString() ?? '',
              maxLength: 4,
              keyboard: TextInputType.number,
              validate: (v) => v.isEmpty || validYear(v)),
        ], onSave: (v) async {
      final start = int.tryParse(v['start'] ?? '');
      final end = int.tryParse(v['end'] ?? '');
      if (start == null || (end != null && end < start)) {
        return const ValidationFailure(message: '');
      }
      return advocateFailure(repository.saveEducation(
          profile.id,
          AdvocateEducation(
              id: value?.id ?? '',
              institution: v['institution'] ?? '',
              qualification: v['qualification'] ?? '',
              startYear: start,
              endYear: end)));
    });
  }

  Future<bool> hours([AdvocateWorkingHours? value]) {
    final l = context.l10n;
    final time = RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$');
    // PostgreSQL serializes minute-precision times with :00 seconds. Closed
    // rows carry null times (parsed as empty); defaults are editor inputs only,
    // and the existing serializer still writes null while isClosed is true.
    String editorTime(String? stored, String fallback) {
      if (stored == null || stored.isEmpty) return fallback;
      final match =
          RegExp(r'^((?:[01][0-9]|2[0-3]):[0-5][0-9])(?::00(?:\.0+)?)?$')
              .firstMatch(stored);
      return match?.group(1) ?? stored;
    }

    return AdvocateFormDialog.show(context,
        title: l.advocateHours,
        notice: l.advocateTimeZone,
        fields: [
          AdvocateFormField('weekday', l.advocateWeekday,
              initial: value?.weekday.toString() ?? '1',
              options: advocateWeekdays(context),
              required: true),
          AdvocateFormField('opens', l.advocateOpens,
              initial: editorTime(value?.opensAt, '09:00'),
              maxLength: 5,
              required: true,
              validate: time.hasMatch),
          AdvocateFormField('closes', l.advocateCloses,
              initial: editorTime(value?.closesAt, '18:00'),
              maxLength: 5,
              required: true,
              validate: time.hasMatch),
          AdvocateFormField('closed', l.advocateClosed,
              initial: value?.isClosed == true ? 'true' : 'false',
              options: {'false': l.advocateHours, 'true': l.advocateClosed},
              required: true),
        ], onSave: (v) async {
      final opens = v['opens'] ?? '';
      final closes = v['closes'] ?? '';
      final closed = v['closed'] == 'true';
      if (!closed && opens.compareTo(closes) >= 0) {
        return const ValidationFailure(message: '');
      }
      return advocateFailure(repository.saveWorkingHours(
          profile.id,
          AdvocateWorkingHours(
              id: value?.id ?? '',
              weekday: int.tryParse(v['weekday'] ?? '') ?? 1,
              opensAt: opens,
              closesAt: closes,
              isClosed: closed)));
    });
  }

  Future<bool> document() {
    final l = context.l10n;
    return AdvocateFormDialog.show(context,
        title: l.advocateDocumentPhoto,
        notice: l.advocateDocumentHint,
        submitLabel: l.advocateDocumentPhoto,
        fields: [
          AdvocateFormField('title', l.advocateDocumentTitle,
              required: true, maxLength: 160),
          AdvocateFormField('kind', l.advocateDocumentKind,
              initial: 'certificate',
              required: true,
              options: {
                'license': l.advocateLicense,
                'certificate': l.advocateCertificate,
                'diploma': l.advocateDiploma,
              }),
          AdvocateFormField('public', l.advocateDocumentPublic,
              initial: 'false',
              required: true,
              options: {
                'false': l.advocateDocumentPrivate,
                'true': l.advocateDocumentPublic,
              }),
        ], onSave: (v) async {
      final picked = await pickProfileImage();
      if (picked == null) return const ValidationFailure(message: '');
      try {
        if (await picked.length() > ProfileAvatarRepository.maxBytes) {
          return const ValidationFailure(message: '');
        }
        final bytes = await picked.readAsBytes();
        final extension = ProfileAvatarRepository.imageExtension(bytes);
        if (extension == null) return const ValidationFailure(message: '');
        return advocateFailure(repository.uploadDocument(
            expertId: profile.id,
            title: v['title'] ?? '',
            kind: v['kind'] ?? 'certificate',
            bytes: bytes,
            contentType: extension == 'jpg' ? 'image/jpeg' : 'image/$extension',
            isPublic: v['public'] == 'true'));
      } finally {
        releaseProfileImage(picked);
      }
    });
  }

  Future<bool> editDocument(AdvocateDocument document) {
    final l = context.l10n;
    return AdvocateFormDialog.show(context,
        title: l.advocateDocuments,
        notice: l.advocateDocumentHint,
        fields: [
          AdvocateFormField('title', l.advocateDocumentTitle,
              initial: document.title, required: true, maxLength: 160),
          AdvocateFormField('kind', l.advocateDocumentKind,
              initial: document.kind,
              required: true,
              options: {
                'license': l.advocateLicense,
                'certificate': l.advocateCertificate,
                'diploma': l.advocateDiploma
              }),
          AdvocateFormField('public', l.advocateDocumentPublic,
              initial: document.isPublic ? 'true' : 'false',
              required: true,
              options: {
                'false': l.advocateDocumentPrivate,
                'true': l.advocateDocumentPublic
              }),
        ],
        onSave: (v) => advocateFailure(repository.updateDocument(
            AdvocateDocument(
                id: document.id,
                title: v['title'] ?? '',
                kind: v['kind'] ?? document.kind,
                objectPath: document.objectPath,
                isPublic: v['public'] == 'true'))));
  }

  Future<bool> request({AdvocateService? service, bool message = false}) {
    final l = context.l10n;
    return AdvocateFormDialog.show(context,
        title: message ? l.advocateMessage : l.advocateConsult,
        notice: l.advocateRequestPrivacy,
        submitLabel: l.advocateSend,
        fields: [
          AdvocateFormField('message', l.advocateRequestMessage,
              required: true, maxLength: 2000, lines: 5),
        ],
        onSave: (v) => advocateFailure(repository.sendRequest(
            expertId: profile.id,
            message: v['message'] ?? '',
            serviceId: service?.id,
            kind: message ? 'message' : 'consultation')));
  }

  Future<bool> review() {
    if (profile.eligibleConsultationIds.isEmpty) return Future.value(false);
    final l = context.l10n;
    final id = profile.eligibleConsultationIds.first;
    return AdvocateFormDialog.show(context,
        title: l.advocateReview,
        notice: l.advocateReviewEligibility,
        fields: [
          AdvocateFormField('rating', l.advocateRating,
              initial: '5',
              required: true,
              options: {for (var i = 1; i <= 5; i++) '$i': '$i'}),
          AdvocateFormField('comment', l.advocateReviewComment,
              required: true, maxLength: 2000, lines: 4),
        ],
        onSave: (v) => advocateFailure(repository.saveReview(
            consultationId: id,
            rating: int.tryParse(v['rating'] ?? '') ?? 5,
            comment: v['comment'] ?? '')));
  }
}

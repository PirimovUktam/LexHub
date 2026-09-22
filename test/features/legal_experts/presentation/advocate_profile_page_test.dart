// 2026-09-22: protects real owner/public control boundaries, awaited saves,
// responsive layout and fresh conversation state. Not hosted deployment proof.
import 'dart:async';

import 'package:dartz/dartz.dart' show Either, Left, Right;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/theme/app_theme.dart';
import 'package:lexhub/features/legal_experts/domain/entities/advocate_profile.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/advocate_profile_repository.dart';
import 'package:lexhub/features/legal_experts/presentation/pages/advocate_inbox_page.dart';
import 'package:lexhub/features/legal_experts/presentation/pages/advocate_profile_editor_page.dart';
import 'package:lexhub/features/legal_experts/presentation/pages/advocate_profile_page.dart';
import '../../../support/l10n_test_app.dart';

class _Repository implements AdvocateProfileRepository {
  bool owner = false;
  bool missing = false;
  Failure? loadFailure;
  bool failSave = false;
  int saves = 0;
  int serviceSaves = 0;
  int serviceDeletes = 0;
  int sends = 0;
  String? sentServiceId;
  String? sentKind;
  String? sentBody;
  String? reviewedConsultation;
  AdvocateProfileInput? savedInput;
  AdvocateDocument? changedDocument;
  Completer<Either<Failure, AdvocateProfile>>? pendingSave;
  final List<AdvocateService> services = [];
  final List<AdvocateDocument> documents = [];
  final List<AdvocateMessage> messages = [];
  List<String> eligible = [];
  String requestStatus = 'pending';

  AdvocateProfile get profile => AdvocateProfile(
      id: 'expert-synthetic',
      userId: 'owner-synthetic',
      firstName: savedInput?.firstName ?? 'Synthetic',
      lastName: savedInput?.lastName ?? 'Advocate',
      fullName: savedInput == null
          ? 'Synthetic Advocate'
          : '${savedInput?.firstName} ${savedInput?.lastName}',
      isOwner: owner,
      isPublished: true,
      verified: true,
      acceptingClients: true,
      experienceYears: 7,
      bio: 'Synthetic professional biography.',
      workplace: 'Synthetic practice',
      address: 'Synthetic public address',
      languages: const ['Uzbek'],
      specializations: const ['Synthetic specialty'],
      services: services.toList(),
      documents: documents.toList(),
      eligibleConsultationIds: eligible);

  AdvocateRequest get request => AdvocateRequest(
      id: 'request-synthetic',
      expertId: 'expert-synthetic',
      requesterId: 'client-synthetic',
      kind: 'consultation',
      message: 'Synthetic enquiry',
      status: requestStatus,
      createdAt: DateTime(2026));

  @override
  Future<Either<Failure, AdvocateProfile>> getProfile(String expertId) async =>
      loadFailure == null ? Right(profile) : Left(loadFailure!);

  @override
  Future<Either<Failure, AdvocateProfile?>> getMyProfile() async =>
      loadFailure == null
          ? Right(missing ? null : (owner ? profile : null))
          : Left(loadFailure!);

  @override
  Future<Either<Failure, AdvocateProfile>> saveProfile(
      AdvocateProfileInput input) async {
    saves++;
    savedInput = input;
    final pending = pendingSave;
    if (pending != null) return pending.future;
    return failSave
        ? const Left(ServerFailure(message: 'INTERNAL_DATABASE_DETAIL'))
        : Right(profile);
  }

  @override
  Future<Either<Failure, AdvocateService>> saveService(
      String expertId, AdvocateService value) async {
    serviceSaves++;
    if (failSave) {
      return const Left(ServerFailure(message: 'INTERNAL_DATABASE_DETAIL'));
    }
    services.removeWhere((s) => s.id == value.id);
    final saved = AdvocateService(
        id: value.id.isEmpty ? 'service-synthetic' : value.id,
        title: value.title,
        description: value.description,
        priceUzs: value.priceUzs,
        durationMinutes: value.durationMinutes,
        deliveryMode: value.deliveryMode,
        isActive: value.isActive);
    services.add(saved);
    return Right(saved);
  }

  @override
  Future<Either<Failure, void>> deleteService(String id) async {
    serviceDeletes++;
    services.removeWhere((s) => s.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, AdvocateDocument>> updateDocument(
      AdvocateDocument document) async {
    changedDocument = document;
    documents.removeWhere((d) => d.id == document.id);
    documents.add(document);
    return Right(document);
  }

  @override
  Future<Either<Failure, AdvocateRequest>> sendRequest(
      {required String expertId,
      required String message,
      String? serviceId,
      String kind = 'consultation'}) async {
    sends++;
    sentServiceId = serviceId;
    sentKind = kind;
    sentBody = message;
    return failSave
        ? const Left(ServerFailure(message: 'INTERNAL_DATABASE_DETAIL'))
        : Right(request);
  }

  @override
  Future<Either<Failure, List<AdvocateRequest>>> getRequests() async =>
      Right([request]);

  @override
  Future<Either<Failure, AdvocateRequest>> getRequest(String id) async =>
      loadFailure == null ? Right(request) : Left(loadFailure!);

  @override
  Future<Either<Failure, List<AdvocateMessage>>> getMessages(String id) async =>
      Right(messages.toList());

  @override
  Future<Either<Failure, AdvocateMessage>> sendMessage(
      String id, String body) async {
    sends++;
    sentBody = body;
    if (failSave) {
      return const Left(ServerFailure(message: 'INTERNAL_DATABASE_DETAIL'));
    }
    final message = AdvocateMessage(
        id: 'reply-synthetic',
        requestId: id,
        senderId: 'synthetic',
        body: body,
        createdAt: DateTime(2026));
    messages.add(message);
    return Right(message);
  }

  @override
  Future<Either<Failure, AdvocateRequest>> updateRequestStatus(
      String id, String status) async {
    requestStatus = status;
    return Right(request);
  }

  @override
  Future<Either<Failure, AdvocateReview>> saveReview(
      {required String consultationId,
      required int rating,
      required String comment}) async {
    reviewedConsultation = consultationId;
    return Right(AdvocateReview(
        id: 'review-synthetic',
        rating: rating,
        comment: comment,
        createdAt: DateTime(2026)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, Widget page,
    {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(l10nTestApp(page,
      locale: const Locale('en'), theme: AppTheme.lightTheme));
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, int index) async {
  final finder = find.byKey(ValueKey('advocate_tab_$index'));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final finder = find.byKey(const ValueKey('advocate_save'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1280, 900)
  ]) {
    testWidgets(
        'public tabs and honest counts fit ${size.width}x${size.height}',
        (tester) async {
      final repo = _Repository();
      repo.services.add(const AdvocateService(
          id: 'service-synthetic',
          title: 'Synthetic service',
          priceUzs: 120000));
      await _pump(tester,
          AdvocateProfilePage(expertId: repo.profile.id, repository: repo),
          size: size);
      expect(find.text('Synthetic Advocate'), findsOneWidget);
      expect(find.text('0 consultations'), findsOneWidget);
      expect(find.text('0 reviews'), findsOneWidget);
      expect(find.text('Edit profile'), findsNothing);
      expect(tester.takeException(), isNull);
      await _tab(tester, 1);
      expect(find.text('Synthetic service'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tab(tester, 2);
      expect(find.textContaining('No reviews yet.'), findsOneWidget);
      expect(find.text('Leave a review'), findsNothing);
      await _tab(tester, 3);
      expect(find.textContaining('Documents are supplied by'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'owner service required validation and real save/delete roundtrip',
      (tester) async {
    final repo = _Repository()..owner = true;
    await _pump(tester, AdvocateProfilePage(repository: repo));
    await _tab(tester, 1);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await _save(tester);
    expect(repo.serviceSaves, 0);
    expect(find.text('Complete this field.'), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('advocate_field_title')),
        'Synthetic new service');
    await _save(tester);
    expect(repo.serviceSaves, 1);
    expect(find.text('Synthetic new service'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Delete'));
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repo.serviceDeletes, 1);
    expect(find.text('Synthetic new service'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'service failure retains input and exposes no internal message or success',
      (tester) async {
    final repo = _Repository()
      ..owner = true
      ..failSave = true;
    await _pump(tester, AdvocateProfilePage(repository: repo));
    await _tab(tester, 1);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('advocate_field_title')),
        'Synthetic retained service');
    await _save(tester);
    expect(repo.serviceSaves, 1);
    expect(find.byKey(const ValueKey('advocate_save_error')), findsOneWidget);
    expect(find.text('INTERNAL_DATABASE_DETAIL'), findsNothing);
    expect(find.text('Information saved.'), findsNothing);
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('advocate_field_title')))
            .controller
            ?.text,
        'Synthetic retained service');
    repo.failSave = false;
    await _save(tester);
    expect(repo.serviceSaves, 2);
    expect(find.text('Synthetic retained service'), findsOneWidget);
  });

  testWidgets(
      'selected service sends actual service id and enquiry, not a booking claim',
      (tester) async {
    final repo = _Repository();
    repo.services.add(const AdvocateService(
        id: 'selected-service', title: 'Synthetic service'));
    await _pump(tester,
        AdvocateProfilePage(expertId: repo.profile.id, repository: repo));
    await _tab(tester, 1);
    final button = find.widgetWithText(FilledButton, 'Request advice').last;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('not a confirmed booking or payment'),
        findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('advocate_field_message')),
        'Synthetic question');
    await _save(tester);
    expect(repo.sends, 1);
    expect(repo.sentServiceId, 'selected-service');
    expect(repo.sentBody, 'Synthetic question');
    expect(repo.sentKind, 'consultation');
    expect(find.textContaining('Enquiry sent.'), findsOneWidget);
  });

  testWidgets(
      'profile save is pending until backend confirms and failure stays editable',
      (tester) async {
    final repo = _Repository()..owner = true;
    repo.pendingSave = Completer<Either<Failure, AdvocateProfile>>();
    await _pump(tester,
        AdvocateProfileEditorPage(repository: repo, profile: repo.profile));
    await tester.enterText(
        find.byKey(const ValueKey('advocate_profile_firstName')), 'Edited');
    final button = find.byKey(const ValueKey('advocate_profile_save'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(repo.saves, 1);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.byType(AdvocateProfileEditorPage), findsOneWidget);
    repo.pendingSave?.complete(
        const Left(ServerFailure(message: 'INTERNAL_DATABASE_DETAIL')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('advocate_profile_error')), findsOneWidget);
    expect(find.text('INTERNAL_DATABASE_DETAIL'), findsNothing);
    expect(repo.savedInput?.firstName, 'Edited');
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('advocate_profile_firstName')))
            .controller
            ?.text,
        'Edited');
  });

  testWidgets(
      'owner edits existing document visibility without altering object identity',
      (tester) async {
    final repo = _Repository()..owner = true;
    repo.documents.add(const AdvocateDocument(
        id: 'doc-synthetic',
        title: 'Synthetic licence',
        kind: 'license',
        objectPath: 'owner-synthetic/document.jpg'));
    await _pump(tester, AdvocateProfilePage(repository: repo));
    await _tab(tester, 3);
    await tester.ensureVisible(find.byTooltip('Edit'));
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('advocate_field_title')),
        'Updated synthetic licence');
    await tester
        .ensureVisible(find.byKey(const ValueKey('advocate_field_public')));
    await tester.tap(find.byKey(const ValueKey('advocate_field_public')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow visitors to view').last);
    await tester.pumpAndSettle();
    await _save(tester);
    expect(repo.changedDocument?.isPublic, isTrue);
    expect(repo.changedDocument?.title, 'Updated synthetic licence');
    expect(repo.changedDocument?.objectPath, 'owner-synthetic/document.jpg');
  });

  testWidgets('review submit uses server eligible consultation only',
      (tester) async {
    final repo = _Repository()..eligible = ['eligible-synthetic'];
    await _pump(tester,
        AdvocateProfilePage(expertId: repo.profile.id, repository: repo));
    await _tab(tester, 2);
    await tester.ensureVisible(find.text('Leave a review'));
    await tester.tap(find.text('Leave a review'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('advocate_field_comment')),
        'Synthetic completed consultation review');
    await _save(tester);
    expect(repo.reviewedConsultation, 'eligible-synthetic');
  });

  testWidgets(
      'inbox opens real thread and advocate can accept but not self-complete',
      (tester) async {
    final repo = _Repository()..owner = true;
    await _pump(tester, AdvocateInboxPage(repository: repo));
    await tester.tap(find.text('Synthetic enquiry'));
    await tester.pumpAndSettle();
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Complete enquiry'), findsNothing);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(repo.requestStatus, 'accepted');
    expect(find.text('Accepted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed message keeps reply; successful retry appears in thread',
      (tester) async {
    final repo = _Repository()..failSave = true;
    await _pump(
        tester,
        AdvocateConversationPage(
            repository: repo, request: repo.request, isAdvocate: false));
    final reply = find.byKey(const ValueKey('advocate_reply'));
    final send = find.byKey(const ValueKey('advocate_send_reply'));
    await tester.ensureVisible(reply);
    await tester.enterText(reply, 'Synthetic reply');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(repo.sends, 1);
    expect(tester.widget<TextFormField>(reply).controller?.text,
        'Synthetic reply');
    expect(find.text('INTERNAL_DATABASE_DETAIL'), findsNothing);
    repo.failSave = false;
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(repo.sends, 2);
    expect(repo.messages.single.body, 'Synthetic reply');
    expect(tester.widget<TextFormField>(reply).controller?.text, isEmpty);
  });

  testWidgets('refresh uses server status and closes a stale compose form',
      (tester) async {
    final repo = _Repository();
    await _pump(tester, AdvocateConversationPage(
        repository: repo, request: repo.request, isAdvocate: false));
    expect(find.byKey(const ValueKey('advocate_reply')), findsOneWidget);
    repo.requestStatus = 'completed';
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('advocate_reply')), findsNothing);
    expect(find.byKey(const ValueKey('advocate_send_reply')), findsNothing);
    repo.loadFailure = const AuthFailure(message: 'INTERNAL_DATABASE_DETAIL');
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('advocate_reply')), findsNothing);
    expect(find.text('INTERNAL_DATABASE_DETAIL'), findsNothing);
  });

  testWidgets(
      'unauthenticated owner access offers sign-in without internal error',
      (tester) async {
    final repo = _Repository()
      ..loadFailure = const AuthFailure(message: 'INTERNAL_DATABASE_DETAIL');
    await _pump(tester, AdvocateProfilePage(repository: repo));
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create professional profile'), findsNothing);
    expect(find.text('INTERNAL_DATABASE_DETAIL'), findsNothing);
  });
}

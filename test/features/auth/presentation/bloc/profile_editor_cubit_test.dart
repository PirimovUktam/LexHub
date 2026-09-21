// 2026-09-21: prevents false save success and deleting a committed avatar.
// Synthetic repository tests; not real Storage or RLS proof.
import 'dart:async';
import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/auth/data/repositories/profile_avatar_repository.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';
import 'package:lexhub/features/auth/presentation/bloc/profile_editor_cubit.dart';
import '../../domain/usecases/auth_usecases_test.dart';

class RecordingAvatars implements ProfileAvatarRepository {
  final removed = <String>[];
  bool failUpload = false;
  bool failRemove = false;
  int uploads = 0;
  @override
  Future<String> upload(String owner, Uint8List bytes) async {
    uploads++;
    if (failUpload) throw StateError('synthetic upload failure');
    return 'new-path';
  }

  @override
  Future<void> remove(String owner, String path) async {
    if (failRemove) throw StateError('synthetic remove failure');
    removed.add(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SavingRepository extends MockAuthRepository {
  bool fail = false;
  bool committedDespiteTimeout = false;
  int saves = 0;
  Completer<void>? pending;
  @override
  Future<Either<Failure, UserProfileEntity>> updateUserProfile(
      UserProfileEntity profile) async {
    saves++;
    await pending?.future;
    if (!fail || committedDespiteTimeout) mockProfile = profile;
    return fail
        ? const Left(NetworkFailure(message: '', code: FailureCode.timeout))
        : Right(profile);
  }
}

void main() {
  late SavingRepository repository;
  late RecordingAvatars avatars;
  late ProfileEditorCubit cubit;
  final p = UserProfileEntity(
      id: 'synthetic-owner',
      fullName: 'Synthetic',
      avatarPath: 'old-path',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
  setUp(() {
    repository = SavingRepository()..mockProfile = p;
    avatars = RecordingAvatars();
    cubit = ProfileEditorCubit(repository, avatars);
  });
  tearDown(() async {
    await cubit.close();
    repository.dispose();
  });
  test('save persists details and publishes returned profile', () async {
    await cubit.save(
        p.copyWith(occupation: 'Tester', dateOfBirth: DateTime(2000, 2, 29)));
    expect(repository.mockProfile?.occupation, 'Tester');
    expect(cubit.state.saved, repository.mockProfile);
    expect(avatars.uploads, 0);
  });
  test('replacement deletes old image only after save succeeds', () async {
    await cubit.save(p, image: Uint8List(12));
    expect(cubit.state.saved?.avatarPath, 'new-path');
    expect(avatars.removed, ['old-path']);
  });
  test('failed save cleans confirmed unreferenced upload without false success',
      () async {
    repository.fail = true;
    await cubit.save(p, image: Uint8List(12));
    expect(cubit.state.saved, isNull);
    expect(cubit.state.error, FailureCode.timeout);
    expect(avatars.removed, ['new-path']);
  });
  test('timeout after commit must never delete the saved image', () async {
    repository
      ..fail = true
      ..committedDespiteTimeout = true;
    await cubit.save(p, image: Uint8List(12));
    expect(repository.mockProfile?.avatarPath, 'new-path');
    expect(avatars.removed, isEmpty);
    expect(cubit.state.error, FailureCode.timeout);
  });
  test('upload failure does not update the profile', () async {
    avatars.failUpload = true;
    await cubit.save(p, image: Uint8List(12));
    expect(repository.saves, 0);
    expect(cubit.state.error, isNotNull);
    expect(avatars.removed, isEmpty);
  });
  test('cleanup failure remains visible without hiding a successful save',
      () async {
    avatars.failRemove = true;
    await cubit.save(p, image: Uint8List(12));
    expect(cubit.state.saved, isNotNull);
    expect(cubit.state.cleanupFailed, isTrue);
  });
  test('duplicate submit while saving makes only one request', () async {
    repository.pending = Completer<void>();
    final first = cubit.save(p);
    expect(cubit.state.saving, isTrue);
    await cubit.save(p);
    expect(repository.saves, 1);
    repository.pending?.complete();
    await first;
    expect(cubit.state.saved, isNotNull);
  });
}

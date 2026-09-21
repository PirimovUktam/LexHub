// 2026-09-21: prevents lossy private field mapping/null clearing/date shifts.
// Unit serialization evidence only, not remote persistence or deployment.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/auth/data/models/user_profile_model.dart';
import 'package:lexhub/features/auth/data/repositories/profile_avatar_repository.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';

void main() {
  final legacy = {
    'id': 'synthetic-owner',
    'full_name': 'Existing Name',
    'created_at': '2026-09-21T00:00:00Z',
    'updated_at': '2026-09-21T00:00:00Z'
  };
  test('legacy profile does not invent structured names or personal details',
      () {
    final profile = UserProfileModel.fromJson(legacy);
    expect(profile.fullName, 'Existing Name');
    expect(profile.firstName, isNull);
    expect(profile.lastName, isNull);
    expect(profile.dateOfBirth, isNull);
    expect(profile.gender, isNull);
  });
  test('all private fields round trip, auth email is never writable', () {
    final json = {
      ...legacy,
      'first_name': 'Synthetic',
      'last_name': 'Citizen',
      'email': 'synthetic@example.invalid',
      'phone': '+998901234567',
      'bio': 'Synthetic biography',
      'address': 'Synthetic address',
      'occupation': 'Tester',
      'gender': 'female',
      'date_of_birth': '2000-02-29',
      'avatar_path': 'synthetic/path.png'
    };
    final profile = UserProfileModel.fromJson(json);
    final encoded = profile.toJson();
    for (final key in json.keys) {
      if (!key.endsWith('_at')) expect(encoded[key], json[key], reason: key);
    }
    final payload = profile.toUpdatePayload();
    expect(
        payload.keys,
        unorderedEquals([
          'full_name',
          'first_name',
          'last_name',
          'phone',
          'bio',
          'address',
          'occupation',
          'date_of_birth',
          'gender',
          'avatar_path'
        ]));
    expect(payload['date_of_birth'], '2000-02-29');
    expect(profile.gender, ProfileGender.female);
  });
  test('copyWith distinguishes omitted nullable values from explicit clear',
      () {
    final p = UserProfileModel.fromJson({
      ...legacy,
      'first_name': 'Synthetic',
      'last_name': 'Citizen',
      'phone': '+998901234567',
      'bio': 'Synthetic',
      'gender': 'male',
      'date_of_birth': '2000-02-29',
      'address': 'Address',
      'occupation': 'Tester',
      'avatar_path': 'path'
    });
    // copyWith returns the domain entity, not the transport model subtype.
    expect(p.copyWith().props, p.props);
    final cleared = p.copyWith(
        firstName: null,
        lastName: null,
        phone: null,
        bio: null,
        gender: null,
        dateOfBirth: null,
        address: null,
        occupation: null,
        avatarPath: null);
    expect([
      cleared.firstName,
      cleared.lastName,
      cleared.phone,
      cleared.bio,
      cleared.gender,
      cleared.dateOfBirth,
      cleared.address,
      cleared.occupation,
      cleared.avatarPath
    ], everyElement(isNull));
    expect(cleared.fullName, p.fullName);
  });
  test('calendar dates reject normalization, timestamps and malformed values',
      () {
    for (final value in [
      '2025-02-29',
      '2000-13-01',
      '2000-00-01',
      '2000-01-32',
      '2000-01-01T00:00:00Z',
      'bad',
      null,
      42
    ]) {
      expect(parseProfileDate(value), isNull, reason: 'invalid calendar value');
    }
    expect(profileDateString(DateTime.utc(2000, 2, 29)), '2000-02-29');
    expect(profileDateString(DateTime(2000, 2, 29)), '2000-02-29');
  });
  test('unknown gender and malformed optional fields remain absent', () {
    final p = UserProfileModel.fromJson({
      ...legacy,
      'gender': 'unexpected',
      'first_name': 42,
      'reputation_points': 'not a number'
    });
    expect(p.gender, isNull);
    expect(p.firstName, isNull);
  });
  test('avatar allowlist rejects SVG, arbitrary bytes and oversized files', () {
    expect(
        ProfileAvatarRepository.imageExtension(
            Uint8List.fromList('<svg>unsafe</svg>'.codeUnits)),
        isNull);
    expect(ProfileAvatarRepository.imageExtension(Uint8List(12)), isNull);
    expect(
        ProfileAvatarRepository.imageExtension(
            Uint8List(ProfileAvatarRepository.maxBytes + 1)),
        isNull);
    expect(
        ProfileAvatarRepository.imageExtension(
            Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0])),
        'png');
  });
}

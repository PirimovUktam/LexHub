// Guards professional-profile parsing, write allowlists and honest statistics.
// Measured 2026-09-22. Unit fixtures do not prove deployed RLS or real CRUD.
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/legal_experts/data/models/advocate_profile_model.dart';
import 'package:lexhub/features/legal_experts/domain/entities/advocate_profile.dart';

void main() {
  Map<String, dynamic> profile() => {
        'id': 'synthetic-expert',
        'user_id': 'synthetic-owner',
        'first_name': 'Synthetic',
        'last_name': 'Advocate',
        'full_name': 'Synthetic Advocate',
        'verified': true,
        'license_number': 'SYNTHETIC-LICENSE',
        'experience_years': 3,
        'reviews_count': 1,
        'rating': '4.0',
        'consultations_count': 2,
        'is_owner': false,
        'is_published': true,
        'specializations': ['Employment'],
        'languages': ['uz', 'en'],
        'services': [
          {
            'id': 'service',
            'title': 'Consultation',
            'price_uzs': '250000',
            'duration_minutes': 30,
            'delivery_mode': 'online',
            'is_active': true,
          }
        ],
        'experience': [
          {
            'id': 'experience',
            'organization': 'Synthetic office',
            'position': 'Advocate',
            'start_date': '2023-01-01',
            'end_date': null,
          }
        ],
        'education': [
          {
            'id': 'education',
            'institution': 'Synthetic institution',
            'qualification': 'Law',
            'start_year': 2018,
            'end_year': 2022,
          }
        ],
        'documents': [
          {
            'id': 'document',
            'title': 'Synthetic certificate',
            'kind': 'certificate',
            'object_path': 'owner/object.pdf',
            'is_public': true,
          }
        ],
        'working_hours': [
          {
            'id': 'hours',
            'weekday': 1,
            'opens_at': '09:00:00',
            'closes_at': '18:00:00',
            'is_closed': false,
          }
        ],
        'reviews': [
          {
            'id': 'review',
            'rating': 4,
            'comment': 'Synthetic feedback',
            'created_at': '2026-09-22T00:00:00Z',
          }
        ],
        'eligible_consultation_ids': ['consultation'],
      };

  test('aggregate preserves all real child rows and nullable fields', () {
    final result = AdvocateProfileModel.fromJson(profile());
    expect(result.id, 'synthetic-expert');
    expect(result.userId, 'synthetic-owner');
    expect(result.fullName, 'Synthetic Advocate');
    expect(result.verified, isTrue);
    expect(result.licenseNumber, 'SYNTHETIC-LICENSE');
    expect(result.rating, 4);
    expect(result.reviewsCount, 1);
    expect(result.consultationsCount, 2);
    expect(result.languages, ['uz', 'en']);
    expect(result.services.single.priceUzs, 250000);
    expect(result.services.single.durationMinutes, 30);
    expect(result.experience.single.endDate, isNull);
    expect(result.education.single.endYear, 2022);
    expect(result.documents.single.isPublic, isTrue);
    expect(result.workingHours.single.opensAt, '09:00:00');
    expect(result.reviews.single.rating, 4);
    expect(result.eligibleConsultationIds, ['consultation']);
  });

  test('empty profile never invents verification, ratings or child data', () {
    final result = AdvocateProfileModel.fromJson({'id': 'expert'});
    expect(result.verified, isFalse);
    expect(result.licenseNumber, isNull);
    expect(result.rating, isNull);
    expect(result.reviewsCount, 0);
    expect(result.consultationsCount, 0);
    expect(result.services, isEmpty);
    expect(result.reviews, isEmpty);
    expect(result.acceptingClients, isFalse);
    expect(result.isPublished, isFalse);
  });

  test('unverified payload cannot advertise license or string verification',
      () {
    final result = AdvocateProfileModel.fromJson({
      ...profile(),
      'verified': 'true',
    });
    expect(result.verified, isFalse);
    expect(result.licenseNumber, isNull);
  });

  test('rating needs a real review count and valid range', () {
    for (final values in [
      {'reviews_count': 0, 'rating': 5},
      {'reviews_count': 1, 'rating': 6},
      {'reviews_count': 1, 'rating': 0},
    ]) {
      expect(AdvocateProfileModel.fromJson({...profile(), ...values}).rating,
          isNull);
    }
  });

  test('owner serialization contains exact writable fields only', () {
    final input = AdvocateProfileInput.fromProfile(
        AdvocateProfileModel.fromJson(profile()));
    final json = AdvocateProfileModel.inputToJson(input);
    expect(json.keys.toSet(), {
      'first_name',
      'last_name',
      'avatar_path',
      'experience_years',
      'workplace',
      'bio',
      'address',
      'public_phone',
      'public_email',
      'specializations',
      'languages',
      'accepting_clients',
      'is_published',
    });
    expect(json['first_name'], 'Synthetic');
    expect(json['specializations'], ['Employment']);
  });

  test('optional empty contact fields serialize null rather than invalid text',
      () {
    final empty = AdvocateProfileModel.inputToJson(const AdvocateProfileInput(
      firstName: 'Synthetic',
      lastName: 'Advocate',
      publicEmail: ' ',
    ));
    expect(empty['public_phone'], isNull);
    expect(empty['public_email'], isNull);
    final explicit =
        AdvocateProfileModel.inputToJson(const AdvocateProfileInput(
      firstName: 'Synthetic',
      lastName: 'Advocate',
      publicEmail: ' synthetic@example.invalid ',
      publicPhone: ' +998000000000 ',
    ));
    expect(explicit['public_email'], 'synthetic@example.invalid');
    expect(explicit['public_phone'], '+998000000000');
    expect(empty['bio'], '');
  });

  test('optional service price distinguishes unknown from free', () {
    final base = {
      'id': 'service',
      'title': 'Consultation',
      'delivery_mode': 'online'
    };
    expect(AdvocateProfileModel.serviceFromJson(base).priceUzs, isNull);
    expect(
        AdvocateProfileModel.serviceFromJson({...base, 'price_uzs': 0})
            .priceUzs,
        0);
    final values = AdvocateProfileModel.serviceToJson(
        const AdvocateService(title: 'Consultation'));
    expect(values['price_uzs'], isNull);
    expect(values.containsKey('id'), isFalse);
    expect(values.containsKey('expert_id'), isFalse);
  });

  test('closed working hours serialize null opening and closing times', () {
    expect(
        AdvocateProfileModel.workingHoursToJson(
            const AdvocateWorkingHours(weekday: 7, isClosed: true)),
        {
          'weekday': 7,
          'opens_at': null,
          'closes_at': null,
          'is_closed': true,
        });
    expect(
        AdvocateProfileModel.workingHoursToJson(
            const AdvocateWorkingHours(weekday: 1))['opens_at'],
        '09:00');
  });

  test('experience calendar dates do not shift through timezone conversion',
      () {
    final values = AdvocateProfileModel.experienceToJson(AdvocateExperience(
      organization: 'Synthetic office',
      position: 'Advocate',
      startDate: DateTime(2020, 1, 2),
      endDate: DateTime(2023, 12, 31),
    ));
    expect(values['start_date'], '2020-01-02');
    expect(values['end_date'], '2023-12-31');
  });

  test('missing identity and malformed child rows fail instead of faking data',
      () {
    for (final value in [
      null,
      [],
      {},
      {'id': ''},
      {'id': 42},
      {
        'id': 'expert',
        'services': [null],
      },
      {
        'id': 'expert',
        'services': [
          {'title': 'Missing identity'}
        ],
      },
      {
        'id': 'expert',
        'languages': [42],
      }
    ]) {
      expect(() => AdvocateProfileModel.fromJson(value), throwsFormatException);
    }
  });

  test('non-finite and fractional integer fields reject malformed responses',
      () {
    for (final value in [double.nan, double.infinity, 'NaN', 1.5]) {
      expect(
          () => AdvocateProfileModel.fromJson({
                'id': 'expert',
                'reviews_count': value,
              }),
          throwsFormatException);
    }
  });
}

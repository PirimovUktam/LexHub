import 'package:lexhub/features/legal_experts/domain/entities/advocate_profile.dart';

/// Parsing fails on missing identity or malformed rows; it never fabricates
/// verification, reviews, completed consultations or professional credentials.
abstract final class AdvocateProfileModel {
  static AdvocateProfile fromJson(Object? value) {
    final json = map(value);
    final verified = json['verified'] == true;
    final reviewCount = integer(json, 'reviews_count');
    final rating = numberOrNull(json['rating']);
    return AdvocateProfile(
      id: requiredText(json, 'id'),
      userId: text(json, 'user_id'),
      firstName: text(json, 'first_name'),
      lastName: text(json, 'last_name'),
      fullName: text(json, 'full_name'),
      avatarPath: optionalText(json['avatar_path']),
      verified: verified,
      licenseNumber: verified ? optionalText(json['license_number']) : null,
      experienceYears: integer(json, 'experience_years'),
      workplace: text(json, 'workplace'),
      bio: text(json, 'bio'),
      address: text(json, 'address'),
      publicPhone: text(json, 'public_phone'),
      publicEmail: text(json, 'public_email'),
      specializations: strings(json['specializations']),
      languages: strings(json['languages']),
      acceptingClients: json['accepting_clients'] == true,
      isPublished: json['is_published'] == true,
      isOwner: json['is_owner'] == true,
      rating: reviewCount > 0 && rating != null && rating >= 1 && rating <= 5
          ? rating
          : null,
      reviewsCount: reviewCount,
      consultationsCount: integer(json, 'consultations_count'),
      services: rows(json['services']).map(serviceFromJson).toList(),
      experience: rows(json['experience']).map(experienceFromJson).toList(),
      education: rows(json['education']).map(educationFromJson).toList(),
      documents: rows(json['documents']).map(documentFromJson).toList(),
      workingHours:
          rows(json['working_hours']).map(workingHoursFromJson).toList(),
      reviews: rows(json['reviews']).map(reviewFromJson).toList(),
      eligibleConsultationIds: strings(json['eligible_consultation_ids']),
    );
  }

  static Map<String, dynamic> inputToJson(AdvocateProfileInput input) => {
        'first_name': input.firstName.trim(),
        'last_name': input.lastName.trim(),
        'avatar_path': input.avatarPath,
        'experience_years': input.experienceYears,
        'workplace': input.workplace.trim(),
        'bio': input.bio.trim(),
        'address': input.address.trim(),
        'public_phone':
            input.publicPhone.trim().isEmpty ? null : input.publicPhone.trim(),
        'public_email':
            input.publicEmail.trim().isEmpty ? null : input.publicEmail.trim(),
        'specializations': input.specializations.map((s) => s.trim()).toList(),
        'languages': input.languages.map((s) => s.trim()).toList(),
        'accepting_clients': input.acceptingClients,
        'is_published': input.isPublished,
      };

  static AdvocateService serviceFromJson(Map<String, dynamic> json) =>
      AdvocateService(
        id: requiredText(json, 'id'),
        title: requiredText(json, 'title'),
        description: text(json, 'description'),
        priceUzs: numberOrNull(json['price_uzs']),
        durationMinutes: optionalInteger(json['duration_minutes']),
        deliveryMode: requiredText(json, 'delivery_mode'),
        isActive: json['is_active'] == true,
        sortOrder: integer(json, 'sort_order'),
      );

  static Map<String, dynamic> serviceToJson(AdvocateService service) => {
        'title': service.title.trim(),
        'description': service.description.trim(),
        'price_uzs': service.priceUzs,
        'duration_minutes': service.durationMinutes,
        'delivery_mode': service.deliveryMode,
        'is_active': service.isActive,
        'sort_order': service.sortOrder,
      };

  static AdvocateExperience experienceFromJson(Map<String, dynamic> json) =>
      AdvocateExperience(
        id: requiredText(json, 'id'),
        organization: requiredText(json, 'organization'),
        position: requiredText(json, 'position'),
        startDate: date(json['start_date']),
        endDate: json['end_date'] == null ? null : date(json['end_date']),
        description: text(json, 'description'),
      );

  static Map<String, dynamic> experienceToJson(AdvocateExperience value) => {
        'organization': value.organization.trim(),
        'position': value.position.trim(),
        'start_date': dateOnly(value.startDate),
        'end_date': value.endDate == null ? null : dateOnly(value.endDate!),
        'description': value.description.trim(),
      };

  static AdvocateEducation educationFromJson(Map<String, dynamic> json) =>
      AdvocateEducation(
        id: requiredText(json, 'id'),
        institution: requiredText(json, 'institution'),
        qualification: requiredText(json, 'qualification'),
        startYear: requiredInteger(json['start_year']),
        endYear: optionalInteger(json['end_year']),
      );

  static Map<String, dynamic> educationToJson(AdvocateEducation value) => {
        'institution': value.institution.trim(),
        'qualification': value.qualification.trim(),
        'start_year': value.startYear,
        'end_year': value.endYear,
      };

  static AdvocateWorkingHours workingHoursFromJson(Map<String, dynamic> json) =>
      AdvocateWorkingHours(
        id: requiredText(json, 'id'),
        weekday: requiredInteger(json['weekday']),
        opensAt: text(json, 'opens_at'),
        closesAt: text(json, 'closes_at'),
        isClosed: json['is_closed'] == true,
      );

  static Map<String, dynamic> workingHoursToJson(AdvocateWorkingHours value) =>
      {
        'weekday': value.weekday,
        'opens_at': value.isClosed ? null : value.opensAt,
        'closes_at': value.isClosed ? null : value.closesAt,
        'is_closed': value.isClosed,
      };

  static AdvocateDocument documentFromJson(Map<String, dynamic> json) =>
      AdvocateDocument(
        id: requiredText(json, 'id'),
        title: requiredText(json, 'title'),
        kind: requiredText(json, 'kind'),
        objectPath: requiredText(json, 'object_path'),
        isPublic: json['is_public'] == true,
      );

  static AdvocateReview reviewFromJson(Map<String, dynamic> json) =>
      AdvocateReview(
        id: requiredText(json, 'id'),
        rating: requiredInteger(json['rating']),
        comment: text(json, 'comment'),
        createdAt: date(json['created_at']),
      );

  static AdvocateRequest requestFromJson(Map<String, dynamic> json) =>
      AdvocateRequest(
        id: requiredText(json, 'id'),
        expertId: requiredText(json, 'expert_id'),
        requesterId: requiredText(json, 'requester_id'),
        serviceId: optionalText(json['service_id']),
        serviceTitle: optionalText(json['service_title']),
        priceUzs: numberOrNull(json['price_uzs']),
        kind: requiredText(json, 'kind'),
        message: requiredText(json, 'message'),
        status: requiredText(json, 'status'),
        createdAt: date(json['created_at']),
      );

  static AdvocateMessage messageFromJson(Map<String, dynamic> json) =>
      AdvocateMessage(
        id: requiredText(json, 'id'),
        requestId: requiredText(json, 'request_id'),
        senderId: requiredText(json, 'sender_id'),
        body: requiredText(json, 'body'),
        createdAt: date(json['created_at']),
      );

  static Map<String, dynamic> map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const FormatException('Invalid advocate response shape');
  }

  static List<Map<String, dynamic>> rows(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('Invalid advocate response list');
    }
    return value.map(map).toList();
  }

  static String text(Map<String, dynamic> json, String key) =>
      optionalText(json[key]) ?? '';

  static String requiredText(Map<String, dynamic> json, String key) {
    final value = optionalText(json[key]);
    if (value == null) {
      throw const FormatException('Missing advocate response field');
    }
    return value;
  }

  static String? optionalText(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Invalid advocate response field');
    }
    return value.trim().isEmpty ? null : value;
  }

  static int integer(Map<String, dynamic> json, String key) =>
      optionalInteger(json[key]) ?? 0;

  static int? optionalInteger(Object? value) =>
      value == null ? null : requiredInteger(value);

  static int requiredInteger(Object? value) {
    final number = numberOrNull(value);
    if (number == null || number.truncateToDouble() != number) {
      throw const FormatException('Invalid advocate response integer');
    }
    return number.toInt();
  }

  static double? numberOrNull(Object? value) {
    if (value == null) return null;
    final number = value is num
        ? value.toDouble()
        : value is String
            ? double.tryParse(value)
            : null;
    if (number == null || !number.isFinite) {
      throw const FormatException('Invalid advocate response number');
    }
    return number;
  }

  static List<String> strings(Object? value) {
    if (value == null) return const [];
    if (value is! List || value.any((entry) => entry is! String)) {
      throw const FormatException('Invalid advocate response strings');
    }
    return value.cast<String>().toList();
  }

  static DateTime date(Object? value) {
    final result = value is String ? DateTime.tryParse(value) : null;
    if (result == null) {
      throw const FormatException('Invalid advocate response date');
    }
    return result;
  }

  static String dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

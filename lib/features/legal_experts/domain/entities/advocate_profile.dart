/// Public professional data, separate from the account's private profile.
/// Verification and aggregates are read-only server decisions.
class AdvocateProfile {
  const AdvocateProfile({
    required this.id,
    this.userId = '',
    this.firstName = '',
    this.lastName = '',
    this.fullName = '',
    this.avatarPath,
    this.verified = false,
    this.licenseNumber,
    this.experienceYears = 0,
    this.workplace = '',
    this.bio = '',
    this.address = '',
    this.publicPhone = '',
    this.publicEmail = '',
    this.specializations = const [],
    this.languages = const [],
    this.acceptingClients = false,
    this.isPublished = false,
    this.isOwner = false,
    this.rating,
    this.reviewsCount = 0,
    this.consultationsCount = 0,
    this.services = const [],
    this.experience = const [],
    this.education = const [],
    this.documents = const [],
    this.workingHours = const [],
    this.reviews = const [],
    this.eligibleConsultationIds = const [],
  });

  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String fullName;
  final String? avatarPath;
  final bool verified;
  final String? licenseNumber;
  final int experienceYears;
  final String workplace;
  final String bio;
  final String address;
  final String publicPhone;
  final String publicEmail;
  final List<String> specializations;
  final List<String> languages;
  final bool acceptingClients;
  final bool isPublished;
  final bool isOwner;
  final double? rating;
  final int reviewsCount;
  final int consultationsCount;
  final List<AdvocateService> services;
  final List<AdvocateExperience> experience;
  final List<AdvocateEducation> education;
  final List<AdvocateDocument> documents;
  final List<AdvocateWorkingHours> workingHours;
  final List<AdvocateReview> reviews;
  final List<String> eligibleConsultationIds;
}

/// Deliberately excludes identity, verification, ratings and counts.
class AdvocateProfileInput {
  const AdvocateProfileInput({
    required this.firstName,
    required this.lastName,
    this.avatarPath,
    this.experienceYears = 0,
    this.workplace = '',
    this.bio = '',
    this.address = '',
    this.publicPhone = '',
    this.publicEmail = '',
    this.specializations = const [],
    this.languages = const [],
    this.acceptingClients = false,
    this.isPublished = false,
  });

  factory AdvocateProfileInput.fromProfile(AdvocateProfile profile) =>
      AdvocateProfileInput(
        firstName: profile.firstName,
        lastName: profile.lastName,
        avatarPath: profile.avatarPath,
        experienceYears: profile.experienceYears,
        workplace: profile.workplace,
        bio: profile.bio,
        address: profile.address,
        publicPhone: profile.publicPhone,
        publicEmail: profile.publicEmail,
        specializations: profile.specializations,
        languages: profile.languages,
        acceptingClients: profile.acceptingClients,
        isPublished: profile.isPublished,
      );

  final String firstName;
  final String lastName;
  final String? avatarPath;
  final int experienceYears;
  final String workplace;
  final String bio;
  final String address;
  final String publicPhone;
  final String publicEmail;
  final List<String> specializations;
  final List<String> languages;
  final bool acceptingClients;
  final bool isPublished;
}

class AdvocateService {
  const AdvocateService({
    this.id = '',
    required this.title,
    this.description = '',
    this.priceUzs,
    this.durationMinutes,
    this.deliveryMode = 'online',
    this.isActive = true,
    this.sortOrder = 0,
  });
  final String id;
  final String title;
  final String description;
  final double? priceUzs;
  final int? durationMinutes;
  final String deliveryMode;
  final bool isActive;
  final int sortOrder;
}

class AdvocateExperience {
  const AdvocateExperience({
    this.id = '',
    required this.organization,
    required this.position,
    required this.startDate,
    this.endDate,
    this.description = '',
  });
  final String id;
  final String organization;
  final String position;
  final DateTime startDate;
  final DateTime? endDate;
  final String description;
}

class AdvocateEducation {
  const AdvocateEducation({
    this.id = '',
    required this.institution,
    required this.qualification,
    required this.startYear,
    this.endYear,
  });
  final String id;
  final String institution;
  final String qualification;
  final int startYear;
  final int? endYear;
}

class AdvocateWorkingHours {
  const AdvocateWorkingHours({
    this.id = '',
    required this.weekday,
    this.opensAt = '09:00',
    this.closesAt = '18:00',
    this.isClosed = false,
  });
  final String id;
  final int weekday;
  final String opensAt;
  final String closesAt;
  final bool isClosed;
}

class AdvocateDocument {
  const AdvocateDocument({
    required this.id,
    required this.title,
    required this.kind,
    required this.objectPath,
    this.isPublic = false,
  });
  final String id;
  final String title;
  final String kind;
  final String objectPath;
  final bool isPublic;
}

class AdvocateReview {
  const AdvocateReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
  final String id;
  final int rating;
  final String comment;
  final DateTime createdAt;
}

class AdvocateRequest {
  const AdvocateRequest({
    required this.id,
    required this.expertId,
    required this.requesterId,
    this.serviceId,
    this.serviceTitle,
    this.priceUzs,
    required this.kind,
    required this.message,
    required this.status,
    required this.createdAt,
  });
  final String id;
  final String expertId;
  final String requesterId;
  final String? serviceId;
  final String? serviceTitle;
  final double? priceUzs;
  final String kind;
  final String message;
  final String status;
  final DateTime createdAt;
}

class AdvocateMessage {
  const AdvocateMessage({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });
  final String id;
  final String requestId;
  final String senderId;
  final String body;
  final DateTime createdAt;
}

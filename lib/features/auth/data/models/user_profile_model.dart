import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';

class UserProfileModel extends UserProfileEntity {
  const UserProfileModel({
    required super.id,
    required super.fullName,
    super.avatarUrl,
    super.phone,
    super.role = UserRole.citizen,
    super.reputationPoints = 10,
    super.isVerified = false,
    super.bio,
    super.firstName,
    super.lastName,
    super.email,
    super.address,
    super.occupation,
    super.avatarPath,
    super.dateOfBirth,
    super.gender,
    required super.createdAt,
    required super.updatedAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    // `try`/`catch (_) {}` OLIB TASHLANDI (§20): ichidagi ikki amal ham
    // exception TASHLAMAYDI (`toString()` null bo'lmagan qiymatda,
    // `DateTime.tryParse` noto'g'ri matnda `null` qaytaradi). O'lik `catch`
    // faqat "xato bu yerda ushlangan" degan yolg'on ishonch berardi.
    final rawCreated = json['created_at'];
    final rawUpdated = json['updated_at'];
    final parsedCreated =
        rawCreated == null ? null : DateTime.tryParse(rawCreated.toString());
    final parsedUpdated =
        rawUpdated == null ? null : DateTime.tryParse(rawUpdated.toString());

    return UserProfileModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Foydalanuvchi',
      avatarUrl: json['avatar_url']?.toString(),
      phone: json['phone']?.toString(),
      role: UserRole.fromString(json['role']?.toString()),
      reputationPoints: json['reputation_points'] is num
          ? (num.tryParse(json['reputation_points'].toString())?.toInt() ?? 10)
          : 10,
      isVerified: json['is_verified'] == true,
      bio: json['bio'] is String ? json['bio'] : null,
      firstName: json['first_name'] is String ? json['first_name'] : null,
      lastName: json['last_name'] is String ? json['last_name'] : null,
      email: json['email'] is String ? json['email'] : null,
      address: json['address'] is String ? json['address'] : null,
      occupation: json['occupation'] is String ? json['occupation'] : null,
      avatarPath: json['avatar_path'] is String ? json['avatar_path'] : null,
      dateOfBirth: parseProfileDate(json['date_of_birth']),
      gender: ProfileGender.parse(json['gender']),
      createdAt: parsedCreated ?? DateTime.now(),
      updatedAt: parsedUpdated ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'phone': phone,
      'role': role.toDbValue(),
      'reputation_points': reputationPoints,
      'is_verified': isVerified,
      'bio': bio,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'address': address,
      'occupation': occupation,
      'avatar_path': avatarPath,
      'date_of_birth': profileDateString(dateOfBirth),
      'gender': gender?.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdatePayload() => {
        'full_name': fullName,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'bio': bio,
        'address': address,
        'occupation': occupation,
        'date_of_birth': profileDateString(dateOfBirth),
        'gender': gender?.name,
        'avatar_path': avatarPath,
      };
}

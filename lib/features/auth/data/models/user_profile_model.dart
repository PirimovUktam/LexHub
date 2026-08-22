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
    required super.createdAt,
    required super.updatedAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreated;
    DateTime? parsedUpdated;
    try {
      if (json['created_at'] != null) {
        parsedCreated = DateTime.tryParse(json['created_at'].toString());
      }
      if (json['updated_at'] != null) {
        parsedUpdated = DateTime.tryParse(json['updated_at'].toString());
      }
    } catch (_) {}

    return UserProfileModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Foydalanuvchi',
      avatarUrl: json['avatar_url']?.toString(),
      phone: json['phone']?.toString(),
      role: UserRole.fromString(json['role']?.toString()),
      reputationPoints: (json['reputation_points'] as num?)?.toInt() ?? 10,
      isVerified: json['is_verified'] == true,
      bio: json['bio']?.toString(),
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Safe map for update profile (excluding protected fields)
  Map<String, dynamic> toUpdatePayload() {
    return {
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'phone': phone,
      'bio': bio,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

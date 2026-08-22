import 'package:equatable/equatable.dart';

enum UserRole {
  citizen,
  lawyer,
  verifiedExpert,
  moderator,
  admin;

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'lawyer':
        return UserRole.lawyer;
      case 'verified_expert':
        return UserRole.verifiedExpert;
      case 'moderator':
        return UserRole.moderator;
      case 'admin':
        return UserRole.admin;
      case 'citizen':
      default:
        return UserRole.citizen;
    }
  }

  String toDbValue() {
    switch (this) {
      case UserRole.lawyer:
        return 'lawyer';
      case UserRole.verifiedExpert:
        return 'verified_expert';
      case UserRole.moderator:
        return 'moderator';
      case UserRole.admin:
        return 'admin';
      case UserRole.citizen:
        return 'citizen';
    }
  }

  /// UI YORLIG'I ATAYLAB BU YERDA YO'Q.
  ///
  /// Ilgari `displayName` getter'i o'zbek matnini domain qatlamida saqlagan
  /// (`'Yurist / Advokat'` ...). Ko'p tilli interfeysda bu yorliq tanlangan
  /// tilga bog'liq bo'lishi kerak, shuning uchun u
  /// `lib/core/localization/role_labels.dart` -> `roleLabelFromDbValue()`
  /// ichiga ko'chirildi. [toDbValue] esa DB kontrakti — TARJIMA QILINMAYDI.
}

/// Represents public profile row associated with auth user
class UserProfileEntity extends Equatable {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? phone;
  final UserRole role;
  final int reputationPoints;
  final bool isVerified;
  final String? bio;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfileEntity({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.phone,
    this.role = UserRole.citizen,
    this.reputationPoints = 10,
    this.isVerified = false,
    this.bio,
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfileEntity copyWith({
    String? id,
    String? fullName,
    String? avatarUrl,
    String? phone,
    UserRole? role,
    int? reputationPoints,
    bool? isVerified,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileEntity(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      reputationPoints: reputationPoints ?? this.reputationPoints,
      isVerified: isVerified ?? this.isVerified,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        avatarUrl,
        phone,
        role,
        reputationPoints,
        isVerified,
        bio,
        createdAt,
        updatedAt,
      ];
}

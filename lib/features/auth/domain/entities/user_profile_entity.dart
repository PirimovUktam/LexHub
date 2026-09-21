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

enum ProfileGender {
  male,
  female;

  static ProfileGender? parse(Object? value) => switch (value) {
        'male' => male,
        'female' => female,
        _ => null,
      };
}

const _unchanged = Object();

/// Own profile from the private RPC; public forum rows use a separate allowlist.
class UserProfileEntity extends Equatable {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? phone;
  final UserRole role;
  final int reputationPoints;
  final bool isVerified;
  final String? bio;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? address;
  final String? occupation;
  final String? avatarPath;
  final DateTime? dateOfBirth;
  final ProfileGender? gender;
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
    this.firstName,
    this.lastName,
    this.email,
    this.address,
    this.occupation,
    this.avatarPath,
    this.dateOfBirth,
    this.gender,
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfileEntity copyWith({
    String? id,
    String? fullName,
    Object? avatarUrl = _unchanged,
    Object? phone = _unchanged,
    UserRole? role,
    int? reputationPoints,
    bool? isVerified,
    Object? bio = _unchanged,
    Object? firstName = _unchanged,
    Object? lastName = _unchanged,
    Object? email = _unchanged,
    Object? address = _unchanged,
    Object? occupation = _unchanged,
    Object? avatarPath = _unchanged,
    Object? dateOfBirth = _unchanged,
    Object? gender = _unchanged,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileEntity(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      avatarUrl: identical(avatarUrl, _unchanged)
          ? this.avatarUrl
          : (avatarUrl is String ? avatarUrl : null),
      phone: identical(phone, _unchanged)
          ? this.phone
          : (phone is String ? phone : null),
      role: role ?? this.role,
      reputationPoints: reputationPoints ?? this.reputationPoints,
      isVerified: isVerified ?? this.isVerified,
      bio: identical(bio, _unchanged) ? this.bio : (bio is String ? bio : null),
      firstName: identical(firstName, _unchanged)
          ? this.firstName
          : (firstName is String ? firstName : null),
      lastName: identical(lastName, _unchanged)
          ? this.lastName
          : (lastName is String ? lastName : null),
      email: identical(email, _unchanged)
          ? this.email
          : (email is String ? email : null),
      address: identical(address, _unchanged)
          ? this.address
          : (address is String ? address : null),
      occupation: identical(occupation, _unchanged)
          ? this.occupation
          : (occupation is String ? occupation : null),
      avatarPath: identical(avatarPath, _unchanged)
          ? this.avatarPath
          : (avatarPath is String ? avatarPath : null),
      dateOfBirth: identical(dateOfBirth, _unchanged)
          ? this.dateOfBirth
          : (dateOfBirth is DateTime ? dateOfBirth : null),
      gender: identical(gender, _unchanged)
          ? this.gender
          : (gender is ProfileGender ? gender : null),
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
        firstName,
        lastName,
        email,
        address,
        occupation,
        avatarPath,
        dateOfBirth,
        gender,
        createdAt,
        updatedAt,
      ];
}

/// A calendar date has no timezone; never convert birth dates to UTC.
String? profileDateString(DateTime? value) => value == null
    ? null
    : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime? parseProfileDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  return parsed != null && profileDateString(parsed) == value ? parsed : null;
}

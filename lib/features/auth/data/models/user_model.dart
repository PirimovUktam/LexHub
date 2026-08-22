import 'package:lexhub/features/auth/domain/entities/user_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    super.phone,
    super.createdAt,
  });

  factory UserModel.fromSupabaseUser(supabase.User user) {
    DateTime? parsedDate;
    try {
      if (user.createdAt.isNotEmpty) {
        parsedDate = DateTime.tryParse(user.createdAt);
      }
    } catch (_) {}

    return UserModel(
      id: user.id,
      email: user.email ?? '',
      phone: user.phone,
      createdAt: parsedDate ?? DateTime.now(),
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    try {
      if (json['created_at'] != null) {
        parsedDate = DateTime.tryParse(json['created_at'].toString());
      }
    } catch (_) {}

    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

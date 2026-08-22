import 'package:equatable/equatable.dart';

/// Represents authenticated user credentials in domain layer
class UserEntity extends Equatable {
  final String id;
  final String email;
  final String? phone;
  final DateTime? createdAt;

  const UserEntity({
    required this.id,
    required this.email,
    this.phone,
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, email, phone, createdAt];
}

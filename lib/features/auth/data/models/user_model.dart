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
    // `try`/`catch (_) {}` OLIB TASHLANDI (§20).
    //
    // Ichida HECH NARSA otmaydi: `user.createdAt` — `String` (nullable EMAS),
    // `isNotEmpty` tashlamaydi, `DateTime.tryParse` esa noto'g'ri matnda
    // exception EMAS, `null` qaytaradi. Ya'ni `catch` shoxi HECH QACHON
    // bajarilmagan — u faqat "bu yerda xato yutiladi" degan YOLG'ON signal
    // berardi (haqiqiy xato paydo bo'lsa ham jimgina yo'qolardi).
    //
    // XATTI-HARAKAT O'ZGARMADI: `tryParse` null qaytarsa, avvalgidek
    // `?? DateTime.now()` ishlaydi.
    final parsedDate = user.createdAt.isNotEmpty
        ? DateTime.tryParse(user.createdAt)
        : null;

    return UserModel(
      id: user.id,
      email: user.email ?? '',
      phone: user.phone,
      createdAt: parsedDate ?? DateTime.now(),
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Ayni sabab: `toString()` null bo'lmagan qiymatda tashlamaydi,
    // `tryParse` esa `null` qaytaradi. `catch` o'lik edi.
    final raw = json['created_at'];
    final parsedDate = raw == null ? null : DateTime.tryParse(raw.toString());

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

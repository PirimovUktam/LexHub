/// `PostgrestException.details` ni `ExpertApplicationCooldown` ga aylantiradi.
///
/// SERVER SHAKLI (`20260830070000_expert_cooldown_machine_readable.sql`):
///   {"lx":"application_cooldown",
///    "retry_at":"2026-08-31T05:00:00+00:00",
///    "reason":"Litsenziya nusxasi o'qilmaydi"}
///
/// `details` XOM SERVER QIYMATI — u matn (PostgREST JSON'da satr sifatida
/// keladi) yoki allaqachon `Map` bo'lishi mumkin, shuning uchun ikkisi ham
/// qabul qilinadi.
///
/// NIMA UCHUN `tryParse` (otmaydi): bu ma'lumot xato YO'LIDA keladi. Agar
/// shakl mos kelmasa — kutayotgan foydalanuvchiga IKKINCHI xato ko'rsatish
/// mantiqsiz; UI avvalgidek umumiy sovutish matnini ko'rsatadi (xatti-harakat
/// PASAYMAYDI). Bu §20 ga zid EMAS: bu yerda hech narsa YASHIRILMAYDI —
/// sabab bo'lmasa UI uni DA'VO QILMAYDI. Shakl buzilsa sabab HAM YO'Q.
library;

import 'dart:convert';

import 'package:lexhub/features/legal_experts/domain/entities/expert_application_cooldown.dart';

abstract final class ExpertApplicationCooldownMapper {
  static const String marker = 'application_cooldown';

  static ExpertApplicationCooldown? tryParse(dynamic details) {
    final map = _asMap(details);
    if (map == null) return null;
    if (map['lx'] != marker) return null;

    final retryRaw = map['retry_at'];
    if (retryRaw is! String) return null;
    final retryAt = DateTime.tryParse(retryRaw);
    if (retryAt == null) return null;

    final reasonRaw = map['reason'];
    final reason = reasonRaw is String && reasonRaw.trim().isNotEmpty
        ? reasonRaw.trim()
        : null;

    return ExpertApplicationCooldown(
      retryAt: retryAt.toLocal(),
      reason: reason,
    );
  }

  static Map<String, dynamic>? _asMap(dynamic details) {
    if (details is Map<String, dynamic>) return details;
    if (details is! String) return null;
    final trimmed = details.trim();
    if (!trimmed.startsWith('{')) return null;
    // JSON EMAS bo'lishi MUMKIN: `details` maydoniga har qanday server matni
    // tushishi mumkin. Shu sababli bu yerda `catch` ATAYLAB bor — u xatoni
    // yashirmaydi, "bu JSON emas" degan MA'LUMOTNI qaytaradi (`null`).
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}

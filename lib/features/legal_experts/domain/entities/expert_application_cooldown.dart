/// SOVUTISH DAVRI MA'LUMOTI — MATNDAN AJRATILGAN.
///
/// NUQSON (2026-08-30 da tuzatildi): `apply_for_expert_verification()`
/// sovutish davrida rad etish SABABINI va qayta topshirish VAQTINI faqat
/// server xato MATNI ichida berardi. `failure_text.dart` o'zbek tilida
/// server matnini aynan ko'rsatadi, boshqa tilda esa `FailureCode` bo'yicha
/// UMUMIY ARB matnini oladi — ya'ni INGLIZ UI'da sabab HAM, vaqt HAM
/// ko'rinmasdi.
///
/// Endi server ayni ikki qiymatni `RAISE ... USING DETAIL` orqali JSON
/// shaklida yuboradi (`20260830070000_expert_cooldown_machine_readable.sql`)
/// va UI matnni O'Z TILIDA quradi. Ya'ni tarjima qilinadigan narsa —
/// SHABLON, qiymat esa xom ma'lumot (§16).
///
/// `reason` MAJBURIY EMAS: server moderatorni sabab yozishga majburlamaydi
/// (`p_rejection_reason DEFAULT NULL`), shuning uchun `null` — HAQIQIY holat,
/// "yo'qolgan ma'lumot" emas. UI sabab yo'q bo'lganda "Sabab:" degan bo'sh
/// sarlavhani KO'RSATMAYDI (§20).
library;

import 'package:equatable/equatable.dart';

class ExpertApplicationCooldown extends Equatable {
  /// Qayta topshirish MUMKIN bo'ladigan payt (serverdan ISO 8601, mahalliy
  /// vaqtga aylantirilgan).
  final DateTime retryAt;

  /// Moderator yozgan sabab. `null` = sabab YOZILMAGAN.
  final String? reason;

  const ExpertApplicationCooldown({required this.retryAt, this.reason});

  @override
  List<Object?> get props => [retryAt, reason];
}

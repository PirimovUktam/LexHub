/// Deadlines Guard Module - monitors, calculates and warns about strict procedural deadlines
class DeadlinesGuard {
  DeadlinesGuard._();

  /// Analyzes query context and returns relevant procedural deadline warning & days
  static DeadlineInfo? evaluateDeadline(String text) {
    final lower = text.toLowerCase();

    // 1. Ishdan bo'shatish (1 oy)
    if (lower.contains("bo'shat") || lower.contains('ishdan ket') || lower.contains('ishga tikla')) {
      return const DeadlineInfo(
        days: 30,
        title: "Mehnat nizosi bo'yicha sudga da'vo muddati",
        description: "Mehnat shartnomasi bekor qilinganligi to'g'risidagi buyruq nusxasi topshirilgan kundan boshlab 1 oy ichida fuqarolik sudiga da'vo arizasi kiritilishi shart (Mehnat kodeksi 560-modda).",
        lawReference: "Mehnat kodeksi 560-modda",
        isCritical: true,
      );
    }

    // 2. YHQ jarimalari / Ma'muriy jarima ustidan shikoyat (10 kun)
    if (lower.contains('jarima') || lower.contains('radar') || lower.contains('yhq') || lower.contains('qaror ustidan')) {
      return const DeadlineInfo(
        days: 10,
        title: "Ma'muriy jarima ustidan shikoyat berish muddati",
        description: "Ma'muriy huquqbuzarlik to'g'risidagi qaror nusxasi topshirilgan kundan boshlab 10 kun ichida yuqori organga yoki sudga shikoyat berilishi lozim (MJtK 315-modda).",
        lawReference: "MJtK 315-modda",
        isCritical: true,
      );
    }

    // 3. Iste'molchi tovar almashtirish (10 kun)
    if (lower.contains('dokon') || lower.contains('tovar') || lower.contains('sotib') || lower.contains('cheki')) {
      return const DeadlineInfo(
        days: 10,
        title: "Tovarni almashtirish yoki qaytarish muddati",
        description: "Nuqsonsiz nooziq-ovqat tovarini xarid qilingan kundan e'tiboran 10 kun ichida almashtirish yoki pulni qaytarib olish huquqiga egasiz.",
        lawReference: "Iste'molchilar huquqlarini himoya qilish to'g'risidagi Qonun 18-modda",
        isCritical: false,
      );
    }

    // 4. Aliment bo'yicha o'tgan davr (3 yil)
    if (lower.contains('aliment') || lower.contains('qarzdorlik')) {
      return const DeadlineInfo(
        days: 1095,
        title: "Alimentni o'tgan davr uchun undirish muddati",
        description: "Aliment sudga murojaat qilingan paytdan boshlab undiriladi. O'tgan davr uchun esa sudga murojaat qilishdan oldingi 3 yillik muddat doirasida undirilishi mumkin.",
        lawReference: "Oila kodeksi 136-modda",
        isCritical: false,
      );
    }

    // 5. Umumiy fuqarolik da'vo muddati (3 yil)
    if (lower.contains('qarz') || lower.contains('shartnoma') || lower.contains('yetkazilgan zarar')) {
      return const DeadlineInfo(
        days: 1095,
        title: "Umumiy da'vo muddati (Iskovaya davnost)",
        description: "Fuqarolik munosabatlarida buzilgan huquqlarni himoya qilish uchun umumiy da'vo muddati 3 yil etib belgilangan (Fuqarolik kodeksi 150-modda).",
        lawReference: "Fuqarolik kodeksi 150-modda",
        isCritical: false,
      );
    }

    return null;
  }
}

class DeadlineInfo {
  final int days;
  final String title;
  final String description;
  final String lawReference;
  final bool isCritical;

  const DeadlineInfo({
    required this.days,
    required this.title,
    required this.description,
    required this.lawReference,
    required this.isCritical,
  });
}

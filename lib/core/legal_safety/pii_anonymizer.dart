/// PII Anonymizer Engine to sanitize sensitive personal data before publishing to community or logs
class PiiAnonymizer {
  PiiAnonymizer._();

  // Uzbekistan phone regex (+998 XX XXX XX XX or local 9X XXX XX XX variations)
  static final RegExp _phoneRegex = RegExp(
    r'(?:\+?998[\s-]?)?\(?(?:90|91|93|94|95|97|98|99|88|33|71|77|\d{2})\)?[\s-]?\d{3}[\s-]?\d{2}[\s-]?\d{2}',
    caseSensitive: false,
  );

  // Passport / ID Card series and 7-digit number (e.g., AA 1234567, FA1234567, ab 1234567)
  static final RegExp _passportRegex = RegExp(
    r'\b[A-Za-z]{2}\s?\d{7}\b',
  );

  // Bank Card numbers (16 digits e.g. 8600 XXXX XXXX XXXX or 9860...)
  static final RegExp _cardRegex = RegExp(
    r'\b(?:\d{4}[\s-]?){3}\d{4}\b',
  );

  // Uzbekistan PINFL (JSHSHIR - 14 consecutive digits)
  static final RegExp _pinflRegex = RegExp(
    r'\b[1-6]\d{13}\b',
  );

  // Email address
  static final RegExp _emailRegex = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
    caseSensitive: false,
  );

  // ── ISM / FAMILIYA ────────────────────────────────────────────────────────
  //
  // NIMA UCHUN KERAK (O'LCHANGAN, 2026-08-26 live test):
  //   asl:  "Mening ismim Aziz Karimov, telefonim +998901234567."
  //   avval: "Mening ismim Aziz Karimov, telefonim [Telefon yashirildi]."
  // Ya'ni telefon yashirinardi, ISM-FAMILIYA esa Legal AI proxy orqali
  // Google'ga va hamjamiyat feed'iga OCHIQ ketardi. Klass nomi "PII
  // anonymizer" bo'lsa-da, amalda faqat strukturali identifikatorlar
  // (telefon/pasport/karta/JSHSHIR/email) tozalanardi.
  //
  // NIMA UCHUN YOLG'IZ SUFFIKS YETARLI EMAS: o'zbekchada ODDIY so'zlar ham
  // `-ov` bilan tugaydi (`sinov muddati`, `tanlov`, `so'rov`, `kuyov`) va
  // ularni o'chirish RAG'ni buzadi — `legal_assistant_remote_datasource.dart`
  // AYNAN sanitizatsiyadan chiqqan matn bo'yicha modda qidiradi. Shuning
  // uchun har bir qoida KONTEKSTGA bog'langan va ustiga `_notNames` filtri
  // qo'yilgan.
  //
  // ANIQ CHEKLOV (halol qayd): gap BOSHIDA turgan yolg'iz familiya
  // ("Karimov meni ishdan bo'shatdi") ushlanmaydi — u yerda `Sinov`,
  // `Kuyov` kabi oddiy so'zlar ham bosh harfli bo'ladi va ularni o'chirish
  // huquqiy ma'noni buzadi. Kirill yozuvidagi `исмим` yorliqlari ham
  // qamrab olinmagan.

  /// `unicode: true` bilan `\p{Lu}`/`\p{Ll}` ishlaydi (O'LCHANGAN: kirill
  /// "Ўзбеков" ham mos keladi), lekin APOSTROF harf emas — shuning uchun
  /// sinfga qo'lda qo'shiladi, aks holda `To‘lqinov` -> `To` bo'lib qirqiladi.
  static const String _up = r'\p{Lu}';
  static const String _lo = r"[\p{Ll}'ʻʼ’‘]";

  /// `\b` ASCII bo'yicha ishlaydi va kirillda ishonchsiz — o'rniga
  /// "atrofi harf EMAS" lookaround'lari.
  static const String _pre = r'(?<![\p{L}])';
  static const String _post = r'(?![\p{L}])';

  /// Familiya suffikslari.
  static const String _sur = r'(?:ov|ova|ev|eva|yev|yeva)';

  static const String _nameMask = '[Ism yashirildi]';

  /// Otasining ismi (`-ovich/-ovna/...`) — o'zbekchada bu shakl faqat
  /// antroponim bo'ladi, ya'ni bir ma'noli.
  static final RegExp _patronymicRegex = RegExp(
    '$_pre$_up$_lo{1,24}(?:ovich|ovna|yevich|yevna|evich|evna)$_post',
    unicode: true,
  );

  /// `Karim o'g'li`, `Aziza qizi`.
  static final RegExp _childOfRegex = RegExp(
    "$_pre$_up$_lo{1,24}\\s+(?:o['ʻʼ’‘]g['ʻʼ’‘]li|qizi)$_post",
    unicode: true,
  );

  /// `ismim / familiyam / F.I.Sh.` yorlig'idan keyingi 1-2 bosh harfli so'z.
  /// 3 emas: "ismim Aziz Karimov Toshkentda" holatida joy nomini yeb
  /// qo'ymaslik uchun — uchinchi bo'lak (otasining ismi) `_patronymicRegex`
  /// bilan ushlanadi.
  static final RegExp _introNameRegex = RegExp(
    '((?:[Mm]ening\\s+)?'
    '(?:[Ii]sm[\\s-]?sharifim|[Ii]smim|[Ff]amiliyam|F\\.?\\s?I\\.?\\s?(?:Sh|O)\\.?)'
    '\\s*[:—–-]?\\s*)'
    '($_up$_lo{1,24}(?:\\s+$_up$_lo{1,24})?)$_post',
    unicode: true,
  );

  /// `Ism Familiya` yoki `Familiya Ism` juftligi.
  static final RegExp _fullNameRegex = RegExp(
    '$_pre(?:$_up$_lo{1,24}\\s+$_up$_lo{0,24}$_sur'
    '|$_up$_lo{0,24}$_sur\\s+$_up$_lo{1,24})$_post',
    unicode: true,
  );

  /// Gap O'RTASIDAGI yolg'iz familiya ("ish beruvchim Karimov ..."). Gap
  /// boshi ATAYLAB qamrab olinmagan (yuqoridagi CHEKLOVGA qarang).
  static final RegExp _loneSurnameRegex = RegExp(
    '(?<=[\\p{Ll},]\\s)$_up$_lo{1,24}$_sur$_post',
    unicode: true,
  );

  /// `-ov/-ev` bilan tugaydigan, lekin ism BO'LMAGAN so'zlar. `sinov
  /// muddati` — mehnat huquqida markaziy tushuncha, uni o'chirish modda
  /// qidiruvini buzadi. Bu so'zlardan biri mos kelgan bo'lakda uchrasa,
  /// BUTUN moslik tegilmasdan qoladi (`So'rov Vazirlar Mahkamasiga` misoli).
  static const Set<String> _notNames = {
    'sinov',
    'tanlov',
    "so'rov",
    'so‘rov',
    'soʻrov',
    'olov',
    'kuyov',
    'ov',
    'yov',
  };

  /// LAVOZIM/ROL so'zlari — ism emas, lekin ismning oldida keladi
  /// (`Sudya Salimova`). Ular SAQLANADI, chunki "kim bilan nizo" degan
  /// ma'no huquqiy javob uchun muhim; faqat ismning o'zi maskalanadi.
  static const Set<String> _titles = {
    'sudya',
    'advokat',
    'prokuror',
    'direktor',
    'rahbar',
    'boshliq',
    'guvoh',
    'fuqaro',
    'notarius',
    'tergovchi',
    'xodim',
    'mudir',
    'shifokor',
  };

  /// Lavozim so'zlarining regex alternativasi (`Sudya|sudya|Advokat|...`).
  static final String _titleAlt = _titles
      .map((t) => '[${t[0].toUpperCase()}${t[0]}]${t.substring(1)}')
      .join('|');

  /// `Advokat Karimov Aziz` — LAVOZIM + familiya + ism.
  ///
  /// NIMA UCHUN ALOHIDA QOIDA: juftlik qoidasi bu holatda faqat
  /// "Advokat Karimov"ni yeb, `Aziz`ni OCHIQ qoldirardi (O'LCHANGAN).
  /// Lavozimdan keyingi bo'lakda familiya SUFFIKSI bo'lishi SHART — aks
  /// holda `Fuqaro Toshkent shahar sudiga` kabi matnda joy nomi
  /// maskalanib, huquqiy ma'no buzilardi.
  static final RegExp _titledNameRegex = RegExp(
    '($_titleAlt)\\s+($_up$_lo{0,24}$_sur(?:\\s+$_up$_lo{1,24})?)$_post',
    unicode: true,
  );

  /// Mos kelgan matndagi ism bo'laklarini maskalaydi.
  ///
  /// Uch xil natija bo'lishi mumkin:
  ///   * oddiy so'z uchrasa — TEGILMAYDI (over-redaction'dan himoya);
  ///   * lavozim so'zi — saqlanadi, yonidagi ism maskalanadi;
  ///   * qolgan hollarda ketma-ket ism bo'laklari BITTA maska bilan
  ///     almashtiriladi ("Aziz Karimov" -> "[Ism yashirildi]").
  static String _maskName(Match match) {
    final matched = match[0]!;
    final tokens = matched.split(RegExp(r'\s+'));
    if (tokens.any((word) => _notNames.contains(word.toLowerCase()))) {
      return matched;
    }
    final out = <String>[];
    var maskJustAdded = false;
    for (final token in tokens) {
      if (_titles.contains(token.toLowerCase())) {
        out.add(token);
        maskJustAdded = false;
        continue;
      }
      if (!maskJustAdded) {
        out.add(_nameMask);
        maskJustAdded = true;
      }
    }
    return out.join(' ');
  }

  /// Anonymizes all sensitive PII from input text
  static String anonymize(String text) {
    if (text.trim().isEmpty) return text;

    String sanitized = text;

    // 1. Bank Cards (replace first to avoid overlapping with shorter numeric patterns)
    sanitized = sanitized.replaceAll(_cardRegex, "[Karta raqami yashirildi]");

    // 2. PINFL / JSHSHIR (14 digits)
    sanitized = sanitized.replaceAll(_pinflRegex, "[JSHSHIR yashirildi]");

    // 3. Uzbekistan Phone Numbers
    sanitized = sanitized.replaceAll(_phoneRegex, "[Telefon yashirildi]");

    // 4. Passport / ID numbers
    sanitized = sanitized.replaceAll(_passportRegex, "[Pasport yashirildi]");

    // 5. Emails
    sanitized = sanitized.replaceAll(_emailRegex, "[Email yashirildi]");

    // 6. Ism / familiya. TARTIB MUHIM: yorliqli holat birinchi (u suffikssiz
    //    ismni ham ushlaydi), keyin bir ma'noli shakllar, oxirida esa
    //    `_notNames` filtri bilan yumshoq qoidalar.
    sanitized = sanitized.replaceAllMapped(
      _introNameRegex,
      (m) => '${m[1]}$_nameMask',
    );
    sanitized = sanitized.replaceAll(_patronymicRegex, _nameMask);
    sanitized = sanitized.replaceAll(_childOfRegex, _nameMask);
    sanitized = sanitized.replaceAllMapped(_titledNameRegex, (m) {
      final tokens = m[2]!.split(RegExp(r'\s+'));
      if (tokens.any((word) => _notNames.contains(word.toLowerCase()))) {
        return m[0]!;
      }
      return '${m[1]} $_nameMask';
    });
    sanitized = sanitized.replaceAllMapped(_fullNameRegex, _maskName);
    sanitized =
        sanitized.replaceAllMapped(_loneSurnameRegex, _maskName);

    return sanitized;
  }

  /// Checks whether input text contains sensitive PII
  static bool containsPii(String text) {
    if (text.isEmpty) return false;
    return _phoneRegex.hasMatch(text) ||
        _passportRegex.hasMatch(text) ||
        _cardRegex.hasMatch(text) ||
        _pinflRegex.hasMatch(text) ||
        _emailRegex.hasMatch(text) ||
        // Ism ham PII: hamjamiyat dialogi (`ask_community_dialog.dart`)
        // ogohlantirishni AYNAN shu getter bo'yicha ko'rsatadi.
        _patronymicRegex.hasMatch(text) ||
        _childOfRegex.hasMatch(text) ||
        _introNameRegex.hasMatch(text) ||
        anonymize(text).contains(_nameMask);
  }
}

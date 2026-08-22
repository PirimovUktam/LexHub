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

    return sanitized;
  }

  /// Checks whether input text contains sensitive PII
  static bool containsPii(String text) {
    if (text.isEmpty) return false;
    return _phoneRegex.hasMatch(text) ||
        _passportRegex.hasMatch(text) ||
        _cardRegex.hasMatch(text) ||
        _pinflRegex.hasMatch(text) ||
        _emailRegex.hasMatch(text);
  }
}

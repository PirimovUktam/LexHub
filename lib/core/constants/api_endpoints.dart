/// API and Backend endpoints configuration for LexHub
class ApiEndpoints {
  ApiEndpoints._();

  /// Ixtiyoriy o'z backend'i (LexHub REST API) manzili.
  ///
  /// P0: BU QIYMAT ILGARI `https://api.lexhub.uz/v1` deb KODGA YOZILGAN edi.
  /// `lexhub.uz` domeni DNS'da MAVJUD EMAS (`nslookup lexhub.uz` → javob yo'q),
  /// ya'ni release APK ichida "dangling" host qolgan edi. Xavf: `.uz` domenini
  /// xohlagan odam ro'yxatdan o'tkazishi mumkin va shu paytdan boshlab har bir
  /// yuridik so'rov — `query_text`, `category`, topilgan qonun chunk'lari —
  /// begona serverga POST qilinardi. Xato esa `catch (_) {}` bilan yutilib,
  /// na foydalanuvchi, na developer buni sezmasdi.
  ///
  /// Shu sababli endi manzil FAQAT ataylab beriladi:
  /// `--dart-define=LEXHUB_API_BASE_URL=https://<haqiqiy-host>/v1`
  /// Berilmasa — [hasBackend] `false`, backend chaqiruvi UMUMAN qilinmaydi.
  static const String baseUrl = String.fromEnvironment('LEXHUB_API_BASE_URL');

  /// Backend manzili ataylab sozlanganmi. `false` bo'lsa HTTP chaqirmaslik shart.
  static bool get hasBackend => baseUrl.isNotEmpty;
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Legal endpoints
  static const String analyzeQuery = '/legal/analyze';
  static const String quickEmergencyRights = '/legal/emergency-rights';
  static const String searchLaws = '/legal/laws/search';
  static const String getArticleByCode = '/legal/laws/article';
  static const String citizenServices = '/citizen/services';
  static const String communityQuestions = '/community/questions';
  static const String expertConsultations = '/experts/consultations';
}

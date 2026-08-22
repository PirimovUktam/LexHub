/// API and Backend endpoints configuration for LexHub
class ApiEndpoints {
  ApiEndpoints._();

  // Production and Supabase endpoints
  static const String baseUrl = 'https://api.lexhub.uz/v1';
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

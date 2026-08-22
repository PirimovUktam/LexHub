import 'package:flutter/foundation.dart';

/// Compile-time configuration for LexHub.
///
/// ## Yagona manba: `--dart-define-from-file`
///
/// Barcha qiymatlar **build vaqtida** kompilyatsiya qilinadi. Runtime'da hech
/// qanday fayl o'qilmaydi.
///
/// ```
/// flutter run                  --dart-define-from-file=env/dev.json
/// flutter test                 --dart-define-from-file=env/dev.json
/// flutter build apk   --release --dart-define-from-file=env/prod.json
/// flutter build appbundle --release --dart-define-from-file=env/prod.json
/// ```
///
/// ## Nima uchun `.env` / `dart:io` / `flutter_dotenv` ishlatilmaydi
///
/// `.env` fayli Android yoki iOS app bundle'ining bir qismi emas. `dart:io`
/// `File('.env')` chaqiruvi qurilmada **hech qachon** topilmaydi, natijada
/// release build'da barcha qiymatlar jimgina bo'sh string bo'lib qoladi va
/// butun backend ishlamay qoladi. Shu sababli runtime file loading butunlay
/// olib tashlangan. Kerakli kalitlar ro'yxati: `env/dev.json.example`.
///
/// ## Secret hygiene
///
/// `env/*.json` fayllari `.gitignore`da. Bu klass hech qachon kalit qiymatini
/// log qilmaydi yoki xato matniga qo'shmaydi — faqat kalit **nomini** ko'rsatadi.
class SupabaseConfig {
  SupabaseConfig._();

  /// Supabase project URL.
  /// `--dart-define=SUPABASE_URL=https://<project-ref>.supabase.co`
  static const String url = String.fromEnvironment('SUPABASE_URL');

  /// Supabase publishable / anon key.
  /// `--dart-define=SUPABASE_ANON_KEY=<publishable-key>`
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Server-side Legal AI proxy (Supabase Edge Function) endpoint.
  ///
  /// Bu **tavsiya etilgan** yo'l: Gemini kaliti serverda qoladi, client faqat
  /// o'z JWT'si bilan proxy'ga murojaat qiladi.
  /// `--dart-define=LEGAL_AI_PROXY_URL=https://<ref>.functions.supabase.co/legal-ai`
  static const String legalAiProxyUrl =
      String.fromEnvironment('LEGAL_AI_PROXY_URL');

  /// `LEGAL_AI_PROXY_URL` mavjudligi.
  static bool get hasLegalAiProxy => legalAiProxyUrl.isNotEmpty;

  /// XAVFLI: faqat local development uchun.
  ///
  /// Release build'da bu qiymat **hech qachon** ishlatilmaydi (pastdagi
  /// [geminiApiKey] getter'i `kReleaseMode`da bo'sh string qaytaradi), va
  /// `env/prod.json.example` ichida `GEMINI_API_KEY` umuman yo'q — ya'ni
  /// production build'ga uzatiladigan qiymat ham mavjud bo'lmaydi.
  static const String _geminiApiKeyDebugOnly =
      String.fromEnvironment('GEMINI_API_KEY');

  /// Gemini API key — **faqat debug/profile** build'da.
  ///
  /// Release build'da doim `''` qaytaradi, shuning uchun mobil clientdan
  /// to'g'ridan-to'g'ri Gemini chaqiruvi production'da o'chirilgan hisoblanadi.
  /// Production'da [legalAiProxyUrl] orqali server-side proxy ishlatilishi kerak.
  static String get geminiApiKey =>
      kReleaseMode ? '' : _geminiApiKeyDebugOnly;

  /// Build to'g'ri sozlanganmi.
  static bool get isConfigured => validate() == null;

  /// Konfiguratsiya to'g'ri bo'lsa `null`, aks holda **secret'siz** xato matni.
  ///
  /// Bu matn faqat kalit nomlarini o'z ichiga oladi; qiymatlar hech qachon
  /// qaytarilmaydi, shuning uchun uni log'ga yoki UI'ga chiqarish xavfsiz.
  static String? validate() {
    final missing = <String>[
      if (url.isEmpty) 'SUPABASE_URL',
      if (anonKey.isEmpty) 'SUPABASE_ANON_KEY',
    ];

    if (missing.isNotEmpty) {
      return 'Build konfiguratsiyasi yetishmayapti: ${missing.join(', ')}. '
          "Ilovani '--dart-define-from-file=env/dev.json' bilan qayta build qiling.";
    }

    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.isScheme('https') || parsed.host.isEmpty) {
      return "SUPABASE_URL to'liq 'https://<project-ref>.supabase.co' "
          "ko'rinishida bo'lishi kerak.";
    }

    return null;
  }

  /// Diagnostika uchun secret'siz xulosa (host + kalit mavjudligi).
  /// Kalitning o'zi hech qachon qaytarilmaydi.
  static Map<String, Object> get redactedDiagnostics => <String, Object>{
        'supabaseHost': Uri.tryParse(url)?.host ?? '<invalid>',
        'anonKeyPresent': anonKey.isNotEmpty,
        'legalAiProxyPresent': hasLegalAiProxy,
        'geminiDirectCallEnabled': geminiApiKey.isNotEmpty,
        'releaseMode': kReleaseMode,
      };

  /// Source-compatibility uchun saqlangan **no-op**.
  ///
  /// Konfiguratsiya endi butunlay compile-time. Hech narsa yuklanmaydi.
  /// Mavjud `test/integration/*` fayllari bu chaqiruvga tayanadi; ular
  /// haqiqiy credential bilan ishlashi uchun test'ni
  /// `flutter test --dart-define-from-file=env/dev.json` bilan ishga tushiring.
  static Future<void> init() async {}

  /// Storage bucket identifiers
  static const String documentsBucket = 'legal-documents';
  static const String avatarsBucket = 'user-avatars';
}

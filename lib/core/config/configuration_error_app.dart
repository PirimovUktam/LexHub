import 'package:flutter/material.dart';
import 'package:lexhub/core/localization/bootstrap_strings.dart';

/// Konfiguratsiya xatosi ekrani — **fail-fast** bootstrap uchun.
///
/// `main()` ichida `SupabaseConfig.validate()` xato qaytarsa, ilova DI'ni ham,
/// `Supabase.initialize`ni ham ishga tushirmaydi va shu ekranni ko'rsatadi.
/// Maqsad: noto'g'ri sozlangan build'ni **birinchi soniyadan** ko'rinadigan
/// qilish, uni tarmoq xatosi yoki auth xatosi bilan aralashtirib bo'lmasligi.
///
/// [details] matni `SupabaseConfig.validate()`dan keladi va konstruksiyasi
/// bo'yicha secret'siz — faqat kalit nomlarini o'z ichiga oladi.
///
/// §16: bu ekran `AppL10n`dan FOYDALANA OLMAYDI — u DI va `Supabase.
/// initialize`dan oldin, localization delegate'lari hali qurilmagan paytda
/// chiziladi. Shuning uchun matnlar `BootstrapStrings` orqali olinadi: u
/// tizim tiliga qarab `uz`/`en` tanlaydi va `uz`ga fallback qiladi.
class ConfigurationErrorApp extends StatelessWidget {
  final String details;

  const ConfigurationErrorApp({super.key, required this.details});

  static const String _buildHint =
      'flutter run --dart-define-from-file=env/dev.json';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.settings_suggest_outlined,
                    size: 56,
                    color: Color(0xFFB3261E),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    BootstrapStrings.configTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B1B1F),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    BootstrapStrings.configBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF49454F),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SelectableText(
                      details,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: Color(0xFFB3261E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B1F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SelectableText(
                      _buildHint,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        fontFamily: 'monospace',
                        color: Color(0xFFE6E1E5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    BootstrapStrings.configKeysHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF79747E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

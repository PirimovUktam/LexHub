import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:lexhub/core/config/configuration_error_app.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/bootstrap_strings.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';
import 'package:lexhub/core/network/timeout_http_client.dart';
import 'package:lexhub/core/telemetry/crash_reporter.dart';
import 'package:lexhub/core/theme/app_theme.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_event.dart';
import 'package:lexhub/features/auth/presentation/pages/auth_gate_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Global Flutter framework error handling (P1 Resilience)
  //
  // YORLIQ HALOLLIGI (o'lchangan, 2026-08-26, Pixel 9 logcat): bu handler
  // ilgari HAR QANDAY `FlutterError`ni "FATAL EXCEPTION" deb yozardi. Real
  // runda logga `[FlutterError FATAL EXCEPTION] A RenderFlex overflowed by 16
  // pixels` va `... ListTile background color or ink splashes may be invisible`
  // tushdi — ikkisi ham layout ogohlantirishi, ilova ulardan keyin normal
  // ishlashda davom etdi. "FATAL" yolg'on signal bo'lib, kelajakdagi crash
  // triage'ni chalg'itadi (CLAUDE.md §0: claim ≠ evidence).
  //
  // AVVAL `details.library` bo'yicha "LAYOUT" / "CAUGHT" deb ajratishga
  // urinib ko'rdim — O'LCHOV BU URINISHNI RAD ETDI: `ListTile` assertion'i
  // `library == 'Flutter framework'` bilan keladi va noto'g'ri "CAUGHT"
  // yorlig'ini oldi. Ilova davom eta oladimi-yo'qmi, bu yerdan ishonchli
  // aniqlanmaydi — shuning uchun DA'VO QILMAYMIZ. `presentError` allaqachon
  // to'liq klassifikatsiyani ("EXCEPTION CAUGHT BY RENDERING LIBRARY" kabi)
  // chiqaradi; bu satr faqat logcat'da qidirish uchun barqaror teg beradi.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError ${details.library ?? "unknown"}] '
        '${details.exception}\n${details.stack}');
    // SERVERGA HAM YOZILADI: release build'da `debugPrint` hech qayerga
    // bormaydi, ya'ni bu satrsiz foydalanuvchi qurilmasidagi crash JIM
    // yo'qoladi. `CrashReporter` Supabase ulanmagan bo'lsa o'zi jim
    // qaytadi (`attach` 5-bosqichdan keyin chaqiriladi).
    CrashReporter.report(
      kind: 'flutter_error',
      error: details.exception,
      stack: details.stack,
      context: details.library,
    );
  };

  // 2. Root Zone & Asynchronous Platform error handling (P1 Resilience)
  //
  // Bu ham "FATAL" EMAS: `return true` protsess crash'ini to'xtatadi, ya'ni
  // xato USHLANGAN. Yorliq shuni aytishi kerak.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformDispatcher unhandled-async caught] $error\n$stack');
    CrashReporter.report(
      kind: 'platform_error',
      error: error,
      stack: stack,
      context: 'PlatformDispatcher.onError',
    );
    return true; // Handled to prevent hard process crash
  };

  // 3. User-friendly Custom ErrorWidget in Release mode
  ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.amberDark, size: 40),
              const SizedBox(height: 12),
              Text(
                BootstrapStrings.fatalTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                kDebugMode
                    ? errorDetails.exception.toString()
                    : BootstrapStrings.fatalHint,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // 4. FAIL-FAST: build-time konfiguratsiya tekshiruvi.
  //
  // Konfiguratsiya `--dart-define-from-file` orqali kompilyatsiya vaqtida
  // kiritiladi. Agar u yetishmasa, ilova DI'ni ham, Supabase'ni ham ishga
  // tushirmaydi va darhol diagnostik ekran ko'rsatadi. Ataylab: soxta URL yoki
  // soxta token bilan davom etish oldingi P0 bug'ning asosiy sababi bo'lgan.
  final configError = SupabaseConfig.validate();
  if (configError != null) {
    debugPrint('[LexHub FATAL CONFIG] $configError');
    debugPrint('[LexHub CONFIG DIAGNOSTICS] ${SupabaseConfig.redactedDiagnostics}');
    runApp(ConfigurationErrorApp(details: configError));
    return;
  }

  // 5. Supabase — bu nuqtada konfiguratsiya tasdiqlangan, shartsiz initialize.
  //
  // `httpClient`: BARCHA Supabase so'rovlariga (PostgREST + Auth + Functions)
  // yagona qat'iy timeout. Chegara so'rov YO'LI bo'yicha tanlanadi
  // (`TimeoutHttpClient.limitFor`): auth 30 s, AI 75 s, CRUD 20 s. Nima uchun
  // global qobiq kerakligi: `lib/core/network/timeout_http_client.dart`.
  //
  // `postgrestOptions.retryEnabled: false` — postgrest 2.9.1 standart holatda
  // GET/HEAD so'rovini HAR QANDAY `Exception` uchun 3 marta qayta yuboradi,
  // ya'ni bizning `TimeoutException` ni ham "qayta urinish" deb qabul qiladi.
  // RUNTIME O'LCHOV (black-hole server, emulator, 2026-08-27): shu sababli
  // Hamjamiyat ekrani 20 s emas, 341–391 s shimmer ko'rsatdi — `getPosts`
  // ketma-ket 3 ta GET qiladi, har biri 4 urinish (~127 s) oldi. Ilova
  // qayta urinishni O'ZI hal qilmaydi: xato ekranida "Qaytadan urinish"
  // tugmasi bor, ya'ni qaror foydalanuvchida qoladi.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.anonKey,
    httpClient: TimeoutHttpClient(http.Client()),
    postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
  );

  // 5.1. Crash sink ulanadi — bu nuqtadan boshlab tutilmagan xatolar
  // `public.client_error_logs` ga yoziladi (`user_id` ni server `auth.uid()`
  // dan oladi, klient yubormaydi).
  CrashReporter.attach(Supabase.instance.client);

  // 6. Dependency Injection
  await initDependencies();

  runApp(const LexHubApp());
}

class LexHubApp extends StatelessWidget {
  const LexHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Til — `sl` ichidagi YAGONA instance (`registerSingleton`), shuning
        // uchun `MaterialApp` qayta qurilsa ham tanlov yo'qolmaydi.
        BlocProvider<LocaleCubit>.value(value: sl<LocaleCubit>()),
        BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>()..add(const CheckAuthStatusEvent()),
        ),
      ],
      // FAQAT `locale:` o'zgaradi — `home:` bir xil widget bo'lib qoladi,
      // shuning uchun Navigator stack, Supabase sessiyasi va BLoC state'lari
      // til almashganda SAQLANADI (§14: logout/data loss BO'LMASIN).
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return MaterialApp(
            onGenerateTitle: (context) => context.l10n.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            locale: locale,
            supportedLocales: AppLocales.supported,
            localizationsDelegates: AppL10n.localizationsDelegates,
            home: const AuthGatePage(),
          );
        },
      ),
    );
  }
}

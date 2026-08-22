import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/config/configuration_error_app.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/bootstrap_strings.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';
import 'package:lexhub/core/theme/app_theme.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lexhub/features/auth/presentation/bloc/auth_event.dart';
import 'package:lexhub/features/auth/presentation/pages/auth_gate_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Global Flutter framework error handling (P1 Resilience)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError FATAL EXCEPTION] ${details.exception}\n${details.stack}');
  };

  // 2. Root Zone & Asynchronous Platform error handling (P1 Resilience)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformDispatcher FATAL EXCEPTION] $error\n$stack');
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
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.anonKey,
  );

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

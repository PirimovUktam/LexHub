import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/app_dimens.dart';

/// MAVZU (theme) — bitta manba.
///
/// QULFLANGAN SIM: `bodyLarge` / `bodyMedium` / `bodySmall` va `hintStyle`
/// qaysi `AppColors` tokeniga ulanishi `test/core/theme/color_contrast_test.dart`
/// tomonidan SHU FAYL MATNIDAN o'qiladi (regex bilan). Ya'ni bu to'rt kalitning
/// rang tokenini o'zgartirish testni yiqitadi — bu ATAYLAB shunday: mavzu
/// darajasidagi matn rangi 65+ ekranda bir vaqtda ko'rinadi, shuning uchun u
/// o'lchovsiz o'zgarmasligi kerak.

class AppTheme {
  AppTheme._();

  /// Light Theme
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: Colors.white,
        secondary: AppColors.indigo,
        onSecondary: Colors.white,
        error: AppColors.emergency,
        onError: Colors.white,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        outline: AppColors.borderLight,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          color: AppColors.textPrimaryLight,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          color: AppColors.textPrimaryLight,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimaryLight,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimaryLight,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(
          color: AppColors.textPrimaryLight,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: AppColors.textPrimaryLight,
          fontSize: 15,
          height: 1.55,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondaryLight,
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: AppColors.textMutedLight,
          fontSize: 12,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondaryLight,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          color: AppColors.textMutedLight,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          color: AppColors.textPrimaryLight,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimaryLight,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      // `FilledButton` yorug' mavzuda ham aniq juftlikka bog'landi (qorong'i
      // mavzudagi izohda sabab yozilgan): navy fon + oq yorliq = 17.85:1.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      // NIMA UCHUN `textButtonTheme` QO'SHILDI: ilgari u YO'Q edi va barcha
      // `TextButton` lar `colorScheme.primary` — ya'ni to'q navy (#0F172A) —
      // rangda chiqardi. Natijada "bosiladigan matn" oddiy sarlavhadan
      // ajralmasdi. `electricBlue` oq ustida 5.17:1 va `backgroundLight`
      // ustida 4.94:1 beradi (AA o'tadi), shu bilan birga bosiladigan
      // element sifatida KO'RINADI.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.electricBlue,
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: AppColors.borderLight, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
        prefixIconColor: AppColors.textMutedLight,
        suffixIconColor: AppColors.textMutedLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.borderStrongLight),
        ),
        // O'LCHANGAN DEFEKT: `borderLight` oq maydon ustida 1.23:1, sahifa foni
        // ustida 1.18:1 — 1.4.11 (3:1) dan past va maydon chegarasi boshqa
        // signal bilan ham berilmagan edi. `borderStrongLight`: 3.30 / 3.15:1.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.borderStrongLight),
        ),
        // FOKUS = AKSENT. Ilgari fokus chegarasi navy edi va `borderLight`
        // dan farqi zaif ko'rinardi. `electricBlue` oq fonda 5.17:1 —
        // grafik element uchun talab 3:1, ya'ni zaxira bilan o'tadi.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.electricBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.emergency),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(
            color: AppColors.emergencyStrong,
            width: 2,
          ),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textMutedLight,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        indicatorColor: AppColors.primary.withValues(alpha: 0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: AppColors.textSecondaryLight,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary);
          }
          return const IconThemeData(color: AppColors.textSecondaryLight);
        }),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondaryLight,
        // M3 `TabBar` ostiga standart bo'luvchi chiziq QO'YADI va u karta
        // hoshiyasi bilan qo'shilib "ikki chiziq" bo'lib ko'rinardi.
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      // Ilgari YORUG' mavzuda `bottomSheetTheme` va `dialogTheme` YO'Q edi:
      // modal oynalar to'rtburchak burchak bilan chiqardi, kartalar esa 18 px
      // radiusli — bir ilovada ikki xil "til". Endi ikkisi ham tokenda.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        modalBackgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      // SNACKBAR — O'LCHANGAN TUZATISH (BATCH 4).
      //
      // Ilgari `snackBarTheme` YO'Q edi va matn rangi M3 default'idan
      // (`onInverseSurface`) kelardi, foni esa har chaqiruv joyida QO'LDA
      // berilardi: `AppColors.crimson` (oq matn ostida 3.76:1),
      // `AppColors.emerald` (2.54:1), `AppColors.amber` (2.15:1). Ya'ni
      // XATO XABARI — foydalanuvchi o'qishi eng zarur matn — WCAG AA
      // (4.5:1) dan past edi. Endi:
      //   • fon markazda qulflandi (`primaryLight`, oq matn bilan 14.63:1);
      //   • matn rangi ATAYLAB `Colors.white` — chaqiruv joylari fonni
      //     `emergencyStrong` (6.47:1), `emeraldStrong` (7.68:1) yoki
      //     `amberStrong` (5.02:1) ga o'zgartirsa ham AA saqlanadi;
      //   • harakat yorlig'i `amberLight` — SHU TO'RT fonning HAMMASIDA
      //     AA'dan o'tadi (13.14 / 5.81 / 6.90 / 4.51). `amberOnTintDark`
      //     `emergencyStrong` ustida 4.49:1 berardi, ya'ni chegaradan past.
      // Qulf: `test/core/theme/color_contrast_test.dart`.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primaryLight,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppColors.amberLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.electricBlue,
        linearTrackColor: AppColors.dividerLight,
      ),
      // NIMA UCHUN `listTileTheme` QO'SHILDI (qurilmada topilgan defekt,
      // `04_til_dark.png`): `ListTile(selected: true)` sarlavha, tavsif va
      // ikonkalarni `colorScheme.primary` bilan bo'yaydi. Bu rang widget
      // MANBASIDA ko'rinmaydi — shuning uchun statik sweep uni topmagan.
      // Yorug' sxemada `primary` allaqachon to'g'ri (oq ustida 17.85:1),
      // ya'ni bu blok pikselni O'ZGARTIRMAYDI; u qorong'i shoxdagi
      // tuzatish bilan JUFT bo'lib turadi va kelajakdagi har qanday
      // `ListTile(selected:)` sayti uchun to'g'ri qiymatni qulflaydi.
      listTileTheme: const ListTileThemeData(
        selectedColor: AppColors.primary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Dark Theme
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.indigo,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      // O'LCHANGAN OGOHLANTIRISH (kutilayotgan xatar, hozir yetib bo'lmaydi):
      // `primary`+`onPrimary` juftligi = `indigo` (#6366F1) + oq = 4.47:1.
      // Bu GRAFIK uchun yetarli (1.4.11 → 3:1) va ayni sabab bilan Checkbox,
      // Switch, ProgressIndicator kabi M3 boshqaruvlari AA'dan o'tadi; lekin
      // MATN uchun (4.5:1) PAST. `FilledButton` M3 da fonni `primary` dan,
      // yorliqni `onPrimary` dan oladi — ya'ni u ishlatilsa AA buzilardi.
      // TEKSHIRILDI: `grep -rn "FilledButton" lib/` → 0 natija, shuning uchun
      // bu yo'l HOZIR yetib bo'lmaydigan. Yangi to'ldirilgan+yorliqli tugma
      // kerak bo'lsa `elevatedButtonTheme` dagi `indigoDark` (oq bilan
      // 6.29:1) ishlatilsin, `colorScheme.primary` EMAS.
      colorScheme: const ColorScheme.dark(
        primary: AppColors.indigo,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryDark,
        onPrimaryContainer: Colors.white,
        secondary: AppColors.emerald,
        onSecondary: Colors.black,
        error: AppColors.emergency,
        onError: Colors.white,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        outline: AppColors.borderDark,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: AppColors.textPrimaryDark,
          fontSize: 15,
          height: 1.55,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondaryDark,
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondaryDark,
          fontSize: 12,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondaryDark,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          color: AppColors.textMutedDark,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // O'LCHANGAN TUZATISH: fon `indigo` (#6366F1) edi va OQ yorliq
          // 4.47:1 berardi — tugma MATNI uchun WCAG AA (4.5:1) dan PAST.
          // `indigoDark` (#4F46E5) bilan 6.29:1. Rang oilasi o'zgarmadi,
          // faqat bir pog'ona to'qroq — qorong'i mavzuda ayni tanlangan
          // kategoriya plitkasi bilan bir xil (`category_grid_widget.dart`).
          backgroundColor: AppColors.indigoDark,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      // LATENT TUZOQ YOPILDI: `colorScheme.primary` = `indigo` + oq `onPrimary`
      // = 4.47:1 — grafik uchun o'tadi, MATN uchun AA'dan past. M3 da
      // `FilledButton` fonni AYNI SHU juftlikdan oladi, ya'ni kimdir birinchi
      // `FilledButton` ni yozgan kunda yorliq jimgina AA'ni buzardi
      // (`grep -rn "FilledButton" lib/` -> hozir 0). Shuning uchun `primary`
      // aksent bo'lib qoladi (grafiklar uchun), to'ldirilgan tugma esa
      // `elevatedButtonTheme` bilan bir xil `indigoDark` + oq = 6.29:1 oladi.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.indigoDark,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      // NIMA UCHUN QORONG'IDA `electricBlueOnDark` (#3B82F6) EMAS: u
      // `cardDark` (#1E293B) ustida 3.98:1 beradi — grafik uchun yetarli,
      // MATN uchun AA'dan past. `blueOnTintDark` (#93C5FD) esa shu yuzada
      // 8.11:1 va ayni rang oilasida qoladi.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blueOnTintDark,
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // O'LCHANGAN TUZATISH: yorliq `indigo` (#6366F1) edi —
          // `backgroundDark` ustida 3.94:1, karta ustida 3.27:1, ya'ni tugma
          // MATNI uchun AA'dan past. `indigoOnTintDark` (#A5B4FC): 8.83:1 /
          // 7.34:1. Yuqoridagi `textButtonTheme` bilan bir xil mantiq.
          foregroundColor: AppColors.indigoOnTintDark,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: AppColors.borderDark, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
        prefixIconColor: AppColors.textMutedDark,
        suffixIconColor: AppColors.textMutedDark,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textMutedDark,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.borderStrongDark),
        ),
        // O'LCHANGAN DEFEKT: `borderDark` `surfaceDark` maydon foni ustida
        // 1.72:1 (kartada 1.41:1) — 1.4.11 (3:1) dan past.
        // `borderStrongDark`: 4.10 / 3.36:1.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.borderStrongDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(
            color: AppColors.electricBlueOnDark,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.emergency),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(
            color: AppColors.emergencyDark,
            width: 2,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.indigo.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.indigo);
          }
          return const IconThemeData(color: AppColors.textSecondaryDark);
        }),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.indigo,
        labelColor: AppColors.textPrimaryDark,
        unselectedLabelColor: AppColors.textSecondaryDark,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        modalBackgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      // SNACKBAR — sabab yorug' mavzudagi bilan AYNI. Qorong'ida M3 default
      // `inverseSurface` YORUG' yuza beradi, ya'ni oq matn deyarli
      // KO'RINMASDI; fon endi `cardDark` (oq matn bilan 14.63:1).
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardDark,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppColors.amberLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.electricBlueOnDark,
        linearTrackColor: AppColors.dividerDark,
      ),
      // QURILMADA O'LCHANGAN DEFEKT (`04_til_dark.png`, piksel: sarlavha
      // #6366F1, karta yuzasi #1E293B): qorong'i sxemada
      // `colorScheme.primary` XOM `indigo`, ya'ni `ListTile(selected: true)`
      // TANLANGAN qatorning sarlavhasini (16 px w700) va tavsifini (14 px)
      // `cardDark` ustida 3.27:1 qilib bo'yardi. Ikkisi ham "yirik matn"
      // EMAS (bold chegara 18.66 px), talab 4.5:1 — demak TANLANGAN qator
      // ekrandagi ENG XIRA matn edi, tanlanmagan qator esa #F8FAFC bilan
      // to'liq kontrastda. `indigoOnTintDark` (#A5B4FC): 7.34:1.
      listTileTheme: const ListTileThemeData(
        selectedColor: AppColors.indigoOnTintDark,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

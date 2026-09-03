// LexHub — BOSH SAHIFADAGI TEZKOR TIL TANLAGICHI.
//
// TALAB: til almashtirish bosh sahifaning ENG YUQORISIDA, darhol ko'zga
// tashlanadigan va bir teginishda ishlaydigan bo'lsin. Ilgari u FAQAT
// Kabinet -> Sozlamalar -> Til yo'lida edi (uch teginish + ikki navigatsiya).
//
// NIMA UCHUN QO'LDA YASALGAN, `SegmentedButton` EMAS:
// Material'ning tanlov widgetlari rangni `colorScheme` dan oladi va bu rang
// widget MANBASIDA ko'rinmaydi. Loyihada aynan shu sinf defekti O'LCHANGAN:
// `ListTile(selected: true)` sarlavhani `colorScheme.primary` bilan bo'yagan
// va qorong'i mavzuda 3.27:1 bergan — xom-rang sweep'i uni KO'RMAGAN, nuqson
// faqat qurilma pikselidan topilgan (`raw_accent_tone_test.dart` izohi,
// `04_til_dark.png`). Shuning uchun bu yerda har bir rang ANIQ yozilgan va
// hammasi `test/core/theme/color_contrast_test.dart` da ALLAQACHON
// qulflangan juftliklardan olingan — YANGI kontrast da'vosi YO'Q:
//
//   tanlangan yorliq  oq / `primary`          17.85:1  (raw_accent_tone:166)
//   tanlangan yorliq  oq / `indigoDark`        6.29:1  (contrast:555)
//   tanlangan CHEGARA `indigoOnTintDark`      >=3:1    (contrast:578 — sabab:
//                     `indigoDark` fon qorong'i sahifada 2.80:1, ya'ni
//                     tanlangan chipning CHETI ko'rinmaydi)
//   tanlanmagan yorliq `textSecondary*`        AA      (contrast:218 / :256)
//
// Tashqi ramka (`border*`) — DEKORATIV guruhlash: holat FILL bilan
// ko'rsatiladi, shuning uchun unga 1.4.11 talabi qo'yilmaydi.
//
// TIL KODI (UZ/EN), tabiiy nom EMAS: "O'zbekcha"+"English" bir qatorda
// telefon kengligida sig'maydi (o'lchov: `expert_apply_dropdown_overflow`
// ishida test shrifti bilan ~290-300 px). Tabiiy nom YO'QOLMAYDI — u
// `Semantics(label:)` va `Tooltip` ichida, ya'ni skrinreader "O'zbekcha"
// deb o'qiydi, "UZ" demaydi.
//
// Ro'yxat `AppLocales.supported` dan QURILADI: yangi til qo'shish uchun
// registrga bitta qator yetadi (`app_locales.dart` kontrakti), bu widget
// tegilmaydi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/locale_cubit.dart';
import 'package:lexhub/core/localization/locale_switch.dart';
import 'package:lexhub/core/theme/app_dimens.dart';

/// Eng kichik teginish maydoni — 44x44.
///
/// ATAYLAB qo'lda yozilgan raqam: `app_dimens.dart` da teginish maydoni
/// tokeni YO'Q va `kMinInteractiveDimension` loyihada hech qayerda
/// ishlatilmaydi. 44 — WCAG 2.5.5 (AAA) va 2.5.8 (AA, 24 px minimumdan
/// yuqori) qiymati.
const double kLanguageTapTarget = 44;

/// Bosh sahifa uchun ixcham til tanlagichi (pill + segmentlar).
class LanguageQuickSwitch extends StatelessWidget {
  const LanguageQuickSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, current) {
        return Semantics(
          container: true,
          label: context.l10n.languagePageTitle,
          child: Material(
            // `Material` UCHTA vazifani bajaradi: ramka (`shape`), segment
            // siyohini pill ichida qirqish (`clipBehavior`) va `InkWell`
            // uchun yuza berish. Fon SHAFFOF — tanlangan chip sahifa foniga
            // qarshi o'lchanadi, xuddi qulflangan test o'lchagandek.
            color: Colors.transparent,
            shape: StadiumBorder(
              side: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    right: AppSpacing.xs,
                  ),
                  child: Icon(
                    Icons.language_rounded,
                    size: AppIconSize.sm,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                for (final locale in AppLocales.supported)
                  _LocaleSegment(
                    locale: locale,
                    selected: locale.languageCode == current.languageCode,
                    isDark: isDark,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LocaleSegment extends StatelessWidget {
  const _LocaleSegment({
    required this.locale,
    required this.selected,
    required this.isDark,
  });

  final Locale locale;
  final bool selected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nativeName = AppLocales.nativeName(locale);

    // Tanlangan yuza: yorug'da `primary` (oq yorliq 17.85:1), qorong'ida
    // `indigoDark` (6.29:1). Chegara IKKI mavzuda ham beriladi — shunda
    // segmentning ichki o'lchami mavzuga qarab O'ZGARMAYDI.
    final fill = selected
        ? (isDark ? AppColors.indigoDark : AppColors.primary)
        : Colors.transparent;
    final edge = selected
        ? (isDark ? AppColors.indigoOnTintDark : AppColors.primary)
        : Colors.transparent;
    final label = selected
        ? Colors.white
        : (isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight);

    return Semantics(
      // Skrinreader TABIIY nomni o'qiydi ("O'zbekcha"), "UZ" ni emas;
      // `selected` esa qaysi til yoqilganini aytadi. `InkWell` shu AYNI
      // tugunga `button` va bosish amalini qo'shadi.
      label: nativeName,
      selected: selected,
      child: Tooltip(
        message: nativeName,
        child: InkWell(
          // `onTap` TANLANGAN segmentda ham beriladi: aks holda u
          // a11y uchun "o'lik" bo'lib qolardi. `switchAppLocale` til
          // o'zgarmaganda o'zi darhol qaytadi (SnackBar ham chiqmaydi).
          onTap: () => switchAppLocale(context, locale),
          // O'LCHANGAN DEFEKT (o'zimning birinchi shaklimda):
          // `ConstrainedBox(minHeight: 44)` YETMAYDI — `AnimatedContainer`
          // `alignment` berilganda MAVJUD BO'SHLIQNI TO'LDIRADI, ya'ni
          // balandlik `maxHeight` gacha o'sadi. Probe (`SafeArea` ichida)
          // segmentni 44x640 / 44x740 / 44x844 / 44x932 deb o'lchadi —
          // butun EKRAN balandligi. `SizedBox(height:)` balandlikni QAT'IY
          // qiladi (44), ichki `Padding` esa ko'rinadigan chipni 36 px
          // qoldiradi. Kenglik o'z-o'zidan to'g'ri edi: `Row` bolaga CHEKSIZ
          // kenglik beradi, shuning uchun `Align` matnga qisqaradi va
          // `minWidth` 44 ga ko'taradi (o'lchandi: 44.0).
          child: SizedBox(
            height: kLanguageTapTarget,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: kLanguageTapTarget,
              ),
              child: Padding(
                // 4 px ichkarilash: TEGINISH maydoni 44x44 QOLADI, ko'zga
                // ko'rinadigan chip esa 36x36 bo'ladi — shu sababli qo'shni
                // ikki chip orasida 8 px bo'shliq ko'rinadi, teginish
                // maydonlari esa YONMA-YON tegib turadi (bo'sh piksel yo'q).
                //
                // O'LCHANDI (probe, 16 holat: 320/360/390/430 x uz/en x
                // light/dark): segment 44.0x44.0, pill 124.0x44.0. Pill
                // BALANDLIGI segment balandligiga TENG — `Material(shape:)`
                // chegarani bolaning USTIGA chizadi, layout'ga 1 px
                // qo'shMAYDI. 124 = 12 (`AppSpacing.md`) + 18
                // (`AppIconSize.sm`) + 6 (`AppSpacing.xs`) + 44 + 44.
                padding: const EdgeInsets.all(AppSpacing.xxs),
                child: AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.base),
                  curve: AppMotion.curve,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: edge),
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      locale.languageCode.toUpperCase(),
                      maxLines: 1,
                      // Mavzu uslubi asos qilib olinadi (xom `fontSize`
                      // yozilmaydi); `?? const TextStyle()` — rang JIMGINA
                      // yo'qolib ketmasligi uchun.
                      style: (theme.textTheme.labelLarge ?? const TextStyle())
                          .copyWith(
                        fontWeight: FontWeight.w800,
                        color: label,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

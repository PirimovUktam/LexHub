// LexHub — `context.l10n` qisqartmasi.
//
// Har bir widget'da `AppL10n.of(context)!` yozish o'rniga bitta joyda
// e'lon qilinadi. `nullable-getter: false` (l10n.yaml) tufayli natija
// non-nullable — ya'ni `!` unwrap ehtiyoji YO'Q (P0 "null check" sinfidagi
// xatolarning yana bir manbasi yopiladi).

import 'package:flutter/widgets.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

export 'package:lexhub/l10n/gen/app_localizations.dart'
    show AppL10n, lookupAppL10n;

extension AppL10nContext on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}

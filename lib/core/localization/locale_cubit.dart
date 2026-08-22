// LexHub — ilova tili STATE'i.
//
// Loyihaning qolgan qismi bilan bir xil naqsh (flutter_bloc). `MaterialApp`
// atrofidagi bitta `BlocBuilder` faqat `locale:` parametrini o'zgartiradi:
// widget daraxti QAYTA QURILMAYDI, Navigator stack saqlanadi, Supabase
// sessiyasi va BLoC'lar tegilmaydi — ya'ni til almashish logout qilmaydi va
// ma'lumot yo'qotmaydi.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/locale_store.dart';

class LocaleCubit extends Cubit<Locale> {
  /// Boshlang'ich qiymat DARHOL store'dan o'qiladi (async emas), shuning uchun
  /// ilova ochilishida "avval o'zbek, keyin ingliz" chaqnashi bo'lmaydi.
  LocaleCubit({required LocaleStore store})
      : _store = store,
        super(store.read());

  final LocaleStore _store;

  /// Tilni o'zgartiradi.
  ///
  /// Tartib MUHIM: avval SAQLAYDI, keyin `emit`. Agar saqlash yiqilsa,
  /// exception chaqiruvchiga qaytadi va UI yolg'on "muvaffaqiyatli" ko'rsatmaydi.
  Future<void> select(Locale locale) async {
    if (!AppLocales.isSupported(locale)) {
      throw ArgumentError.value(
        locale.languageCode,
        'locale',
        'qo\'llab-quvvatlanmaydigan til',
      );
    }
    if (locale.languageCode == state.languageCode) return;
    await _store.write(locale);
    emit(locale);
  }
}

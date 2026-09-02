/// Global Search HOLAT EKRANLARI — OVERFLOW guard.
///
/// RUNTIME EVIDENCE (`.runtime_evidence/s22_blackhole_timeout.png`): black-hole
/// TCP server bilan timeout sun'iy chaqirilganda xato ekrani chiqdi, LEKIN
/// ustida "BOTTOM OVERFLOWED BY 90 PIXELS" bo'ldi — chunki `error` va `empty`
/// shoxlari `Center > Padding > Column` edi. Klaviatura ochiq holatda body
/// balandligi qisqaradi va markazlashtirilgan `Column` sig'may qoladi.
/// `.runtime_evidence/s23_timeout_no_overflow.png` — AYNI SHU kadr geometriyasi
/// tuzatishdan keyin: overflow bandi yo'q, scroll indikatori bor.
///
/// Bu test uch narsani qulflaydi:
///   1. MEXANIZM — tanlangan viewport HAQIQATAN tor: eski `Center > Column`
///      shakli shu o'lchamda overflow beradi (aks holda 2-3 tekshiruv bo'sh
///      bo'lib qolardi);
///   2. XATO holati — `SearchPage` xato ekrani shu viewport'da overflow
///      BERMAYDI va "Qaytadan urinish" harakati mavjud;
///   3. BO'SH holat — `empty` shoxi ham xuddi shunday.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/features/search/domain/repositories/search_repository.dart';
import 'package:lexhub/features/search/domain/usecases/global_search_usecase.dart';
import 'package:lexhub/features/search/presentation/bloc/search_bloc.dart';
import 'package:lexhub/features/search/presentation/bloc/search_event.dart';
import 'package:lexhub/features/search/presentation/bloc/search_state.dart';
import 'package:lexhub/features/search/presentation/pages/search_page.dart';

import '../support/l10n_test_app.dart';

/// Klaviatura ochiq holatda qoladigan tor viewport (logik piksel).
/// AppBar (56) + filter chiplari (54) ayrilgandan keyin body ~150 px qoladi.
const Size _kSqueezedLogicalSize = Size(360, 260);

/// Hech qachon chaqirilmaydigan repozitoriy: `_FrozenSearchBloc.add` barcha
/// hodisalarni bloklaydi, shuning uchun bu yerga oqim yetib bormaydi.
/// `noSuchMethod` — mock kutubxonasiz interfeysni qanoatlantirish usuli.
class _UnusedSearchRepository implements SearchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Testda repozitoriy chaqirilmasligi kerak');
}

/// Holati QOTIB QOLGAN bloc: `SearchPage` ichidagi `BlocProvider` avtomatik
/// `LoadSearchInitialEvent` qo'shadi — `add` bloklanmasa u holatni `initial`
/// ga qaytarib, tekshirmoqchi bo'lgan ekranni yo'q qiladi.
class _FrozenSearchBloc extends SearchBloc {
  _FrozenSearchBloc(SearchState forced)
      : super(
          globalSearchUseCase: GlobalSearchUseCase(_UnusedSearchRepository()),
        ) {
    emit(forced);
  }

  @override
  void add(SearchEvent event) {}
}

Future<void> _pumpSearchPage(WidgetTester tester, SearchState state) async {
  sl.registerFactory<SearchBloc>(() => _FrozenSearchBloc(state));
  addTearDown(() => sl.unregister<SearchBloc>());

  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = _kSqueezedLogicalSize;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(l10nTestApp(const SearchPage(initialQuery: 'mehnat')));
  await tester.pump();
}

void main() {
  testWidgets('MEXANIZM: eski `Center > Column` shakli shu viewport\'da overflow beradi',
      (tester) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = _kSqueezedLogicalSize;
    addTearDown(tester.view.reset);

    // s22 dagi shakl: markazlashtirilgan, scroll qobig'isiz ustun.
    await tester.pumpWidget(l10nTestApp(
      Scaffold(
        appBar: AppBar(
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(54),
            child: SizedBox(height: 54),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 12),
                const Text('Server javob bermadi.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Qaytadan urinish'),
                ),
              ],
            ),
          ),
        ),
      ),
    ));

    final error = tester.takeException();
    expect(
      error,
      isA<FlutterError>(),
      reason: 'Viewport yetarlicha tor emas — quyidagi tekshiruvlar bo\'sh '
          'bo\'lib qoladi. `_kSqueezedLogicalSize` ni kichraytir.',
    );
    expect(error.toString(), contains('overflowed'));
  });

  testWidgets('XATO holati: overflow yo\'q va qayta urinish harakati bor',
      (tester) async {
    await _pumpSearchPage(
      tester,
      const SearchState(
        status: SearchStatus.error,
        query: 'mehnat',
        errorMessage: 'Server javob bermadi.',
        errorCode: FailureCode.timeout,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
  });

  testWidgets('BO\'SH holati: overflow yo\'q', (tester) async {
    await _pumpSearchPage(
      tester,
      const SearchState(status: SearchStatus.empty, query: 'zzzz'),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
  });
}

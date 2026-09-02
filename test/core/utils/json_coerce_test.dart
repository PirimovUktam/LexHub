// `json_coerce.dart` KONTRAKTI — entity'lar shu funksiyalarga tayanadi,
// shuning uchun har bir tur uchun kutilgan natija QULFLANADI.
//
// ASOSIY DA'VO: bu funksiyalar HECH QACHON exception tashlamaydi. Sabab —
// ilgari `json['x'] as String?` shakli model/cache noto'g'ri tur qaytarganda
// butun huquqiy javobni `ServerException`ga aylantirardi.

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/utils/json_coerce.dart';

void main() {
  group('jsonText', () {
    test('String o\'zi qaytadi, num matnga o\'giriladi', () {
      expect(jsonText('161-modda'), '161-modda');
      expect(jsonText(161), '161');
      expect(jsonText(16.5), '16.5');
    });

    test('bool / Map / List / null -> null (matn sifatida MA\'NOSIZ)', () {
      expect(jsonText(true), isNull);
      expect(jsonText(null), isNull);
      expect(jsonText(<String, dynamic>{'a': 1}), isNull);
      expect(jsonText(<int>[1, 2]), isNull);
    });
  });

  group('jsonFlag', () {
    test('bool, 1/0 va "true"/"false" tushuniladi', () {
      expect(jsonFlag(true), isTrue);
      expect(jsonFlag(false), isFalse);
      expect(jsonFlag(1), isTrue);
      expect(jsonFlag(0), isFalse);
      expect(jsonFlag('true'), isTrue);
      expect(jsonFlag('  FALSE '), isFalse);
    });

    test('noaniq qiymatlar -> null (chaqiruvchi standartga tushadi)', () {
      expect(jsonFlag(2), isNull);
      expect(jsonFlag('ha'), isNull);
      expect(jsonFlag(null), isNull);
      expect(jsonFlag(<String, dynamic>{}), isNull);
    });
  });

  group('jsonInt', () {
    test('int, double va raqamli satr', () {
      expect(jsonInt(30), 30);
      expect(jsonInt(30.0), 30);
      expect(jsonInt(29.6), 30);
      expect(jsonInt('30'), 30);
      expect(jsonInt(' 30.4 '), 30);
    });

    test('raqam bo\'lmagan qiymat va cheksizlik -> null', () {
      expect(jsonInt('o\'ttiz kun'), isNull);
      expect(jsonInt(double.infinity), isNull);
      expect(jsonInt(double.nan), isNull);
      expect(jsonInt(null), isNull);
      expect(jsonInt(true), isNull);
    });
  });

  group('jsonMap', () {
    test('Map<String, dynamic> o\'zi qaytadi', () {
      final map = <String, dynamic>{'summary': 'x'};
      expect(jsonMap(map), same(map));
    });

    test('Map<dynamic, dynamic> (Hive cache) kalitlari String\'ga o\'giriladi',
        () {
      final hiveLike = <dynamic, dynamic>{'summary': 'x', 1: 'bir'};
      final result = jsonMap(hiveLike);
      expect(result, isA<Map<String, dynamic>>());
      expect(result!['summary'], 'x');
      expect(result['1'], 'bir');
    });

    test('Map bo\'lmagan qiymat -> null', () {
      expect(jsonMap('matn'), isNull);
      expect(jsonMap(<int>[1]), isNull);
      expect(jsonMap(null), isNull);
    });
  });
}

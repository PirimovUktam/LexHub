import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/community_forum/data/datasources/answer_schema.dart';
import 'package:lexhub/features/community_forum/data/models/question_answer_model.dart';

import '../../../../support/source_scan.dart';

/// COMMUNITY ANSWER FLOW — SCHEMA & RBAC GUARD
///
/// MUHIM CHEKLOV (CLAIM != EVIDENCE): bu fayl pure Dart testlari. U live
/// Supabase'da javob saqlanishini ISBOTLAMAYDI — buni faqat
/// `test/integration/verify_community_answer_live_test.dart` (gated) va real
/// device qiladi. Bu testlar quyidagi REAL evidence'ni qo'riqlaydi:
///
/// LIVE CLOUD EVIDENCE (2026-08-22, prod publishable key, read-only GET):
///   GET /rest/v1/answers?select=content -> 400 42703 (column does not exist)
///   GET /rest/v1/answers?select=body    -> 200
///   Content-Range: */0                  (answers jadvali BO'SH)
/// REAL DEVICE EVIDENCE (2026-08-22, release APK):
///   "Could not find the 'content' column of 'answers' in the schema cache"
void main() {
  group('REAL COLUMN MAPPING — payload live schema bilan mos', () {
    test("payload matnni `body` ga yozadi, `content` YUBORMAYDI", () {
      final payload = buildAnswerInsertPayload(
        questionId: 'q-1',
        userId: 'u-1',
        text: 'Mehnat kodeksining 173-moddasiga qarang.',
        isExpert: false,
        canPostAsExpert: false,
      );

      expect(kAnswerTextColumn, 'body');
      expect(payload['body'], 'Mehnat kodeksining 173-moddasiga qarang.');
      expect(payload.containsKey('content'), isFalse,
          reason: 'live `answers.content` MAVJUD EMAS (42703) — '
              'kalit payloadda bo\'lsa PostgREST PGRST204 beradi');
    });

    test('payload faqat live\'da mavjudligi tasdiqlangan ustunlarni yuboradi',
        () {
      final payload = buildAnswerInsertPayload(
        questionId: 'q-1',
        userId: 'u-1',
        text: 'javob',
        isExpert: false,
        canPostAsExpert: false,
      );
      // Har biri live'da GET select bilan 200 qaytargan.
      expect(payload.keys.toSet(), <String>{
        'question_id',
        'user_id',
        'body',
        'is_expert_answer',
        'is_accepted',
        'upvotes_count',
        'legal_references',
      });
    });

    test('matn trim qilinadi va bo\'sh matn RAD ETILADI', () {
      final payload = buildAnswerInsertPayload(
        questionId: 'q-1',
        userId: 'u-1',
        text: '   javob matni   ',
        isExpert: false,
        canPostAsExpert: false,
      );
      expect(payload['body'], 'javob matni');

      expect(
        () => buildAnswerInsertPayload(
          questionId: 'q-1',
          userId: 'u-1',
          text: '   ',
          isExpert: false,
          canPostAsExpert: false,
        ),
        throwsA(isA<AnswerContentException>()),
      );
    });

    test('client SOXTA huquqiy iqtibos qo\'shmaydi', () {
      final payload = buildAnswerInsertPayload(
        questionId: 'q-1',
        userId: 'u-1',
        text: 'javob',
        isExpert: true,
        canPostAsExpert: true,
      );
      expect(payload['legal_references'], isEmpty,
          reason: 'eski kod ekspert javobiga o\'ylab topilgan '
              '"Lex.uz rasmiy qonunchilik normasi" iqtibosini qo\'shardi');
    });
  });

  group('WRONG ROLE REJECTION — citizen ekspert javobi yoza olmaydi', () {
    test('canAnswerAsExpert matritsasi', () {
      // Faqat tasdiqlangan yurist/ekspert.
      expect(canAnswerAsExpert(role: 'lawyer', isVerified: true), isTrue);
      expect(canAnswerAsExpert(role: 'verified_expert', isVerified: true),
          isTrue);
      // Rol to'g'ri, lekin `is_verified = false` -> HUQUQ YO'Q.
      expect(canAnswerAsExpert(role: 'lawyer', isVerified: false), isFalse);
      expect(canAnswerAsExpert(role: 'verified_expert', isVerified: false),
          isFalse);
      // Citizen — live'dagi BARCHA foydalanuvchilar shu holatda.
      expect(canAnswerAsExpert(role: 'citizen', isVerified: true), isFalse);
      expect(canAnswerAsExpert(role: 'citizen', isVerified: false), isFalse);
      // Admin/moderator ham ekspert javobi bermaydi (biznes qoidasi:
      // ekspert javobi = huquqiy javobgarlik, moderatsiya emas).
      expect(canAnswerAsExpert(role: 'admin', isVerified: true), isFalse);
      expect(canAnswerAsExpert(role: 'moderator', isVerified: true), isFalse);
      // Fail-closed: rol yo'q / bo'sh / noma'lum.
      expect(canAnswerAsExpert(role: null, isVerified: true), isFalse);
      expect(canAnswerAsExpert(role: '  ', isVerified: true), isFalse);
      expect(canAnswerAsExpert(role: 'LAWYER', isVerified: true), isTrue,
          reason: 'normalizatsiya: katta harf ham qabul qilinadi');
    });

    test('huquqsiz foydalanuvchi is_expert_answer=true YUBORA OLMAYDI', () {
      expect(
        () => buildAnswerInsertPayload(
          questionId: 'q-1',
          userId: 'citizen-1',
          text: 'men advokatman',
          isExpert: true,
          canPostAsExpert: false,
        ),
        throwsA(isA<ExpertAnswerNotAuthorizedException>()),
        reason: 'jimgina FALSE ga tushirish = yolg\'on success',
      );
    });

    test('huquqsiz foydalanuvchi ODDIY javob yozishi mumkin', () {
      final payload = buildAnswerInsertPayload(
        questionId: 'q-1',
        userId: 'citizen-1',
        text: 'mening fikrim',
        isExpert: false,
        canPostAsExpert: false,
      );
      expect(payload['is_expert_answer'], isFalse);
      expect(payload['body'], 'mening fikrim');
    });

    test('haqli foydalanuvchi ekspert javobi yozadi', () {
      final payload = buildAnswerInsertPayload(
        questionId: 'q-1',
        userId: 'lawyer-1',
        text: 'MK 173-modda',
        isExpert: true,
        canPostAsExpert: true,
      );
      expect(payload['is_expert_answer'], isTrue);
    });

    test('kExpertAnswerRoles DB triggeri bilan bir xil', () {
      // `enforce_expert_answer()`:
      //   role NOT IN ('verified_expert','lawyer') OR is_verified IS NOT TRUE
      expect(kExpertAnswerRoles, <String>{'lawyer', 'verified_expert'});
    });
  });

  group('ANSWER READ — matn live `body` ustunidan o\'qiladi', () {
    test('`body` dan o\'qiladi (live holati)', () {
      expect(readAnswerText({'body': 'javob matni'}), 'javob matni');
    });

    test('`content` legacy fallback sifatida qoladi', () {
      // Repo migration\'idan qurilgan bazada eski qatorlar `content` da.
      expect(readAnswerText({'content': 'eski javob'}), 'eski javob');
      expect(readAnswerText({'body': '', 'content': 'eski javob'}),
          'eski javob');
      expect(readAnswerText({'body': 'yangi', 'content': 'eski'}), 'yangi',
          reason: '`body` birinchi o\'rinda');
    });

    test('matn topilmasa null (jimgina bo\'sh string EMAS)', () {
      expect(readAnswerText({}), isNull);
      expect(readAnswerText({'body': '   '}), isNull);
      expect(readAnswerText({'body': null, 'content': null}), isNull);
      expect(readAnswerText({'body': 42}), isNull,
          reason: 'String bo\'lmagan qiymat cast xatosi bermasligi kerak');
    });

    test('REGRESSIYA: live qatorida javob matni UI\'ga yetib boradi', () {
      // Live PostgREST qaytaradigan shakl (`content` ustuni YO'Q).
      final model = QuestionAnswerModel.fromJson({
        'id': 'a-1',
        'question_id': 'q-1',
        'user_id': 'u-1',
        'body': 'Mehnat kodeksi 173-moddasi.',
        'is_expert_answer': false,
        'is_accepted': false,
        'upvotes_count': 0,
        'legal_references': <dynamic>[],
        'created_at': '2026-08-22T06:14:59.544972+00:00',
        'profiles': {'full_name': 'Oʻktam', 'role': 'citizen'},
      });

      expect(model.content, 'Mehnat kodeksi 173-moddasi.',
          reason: 'eski kod `json[\'content\']` o\'qib HAR DOIM \'\' bergan '
              '— javob saqlansa ham UI\'da bo\'sh ko\'rinardi');
      expect(model.authorName, 'Oʻktam');
      expect(model.authorRole, 'citizen');
      expect(model.isExpert, isFalse);
      expect(model.createdAt.year, 2026);
    });

    test('citizen profili avtomatik ekspert deb belgilanmaydi', () {
      final model = QuestionAnswerModel.fromJson({
        'id': 'a-1',
        'body': 'javob',
        'created_at': '2026-08-22T06:14:59Z',
        'profiles': {'full_name': 'Fuqaro', 'role': 'citizen'},
      });
      expect(model.isExpert, isFalse);
    });

    test('toJson -> fromJson round-trip matnni saqlaydi', () {
      final original = QuestionAnswerModel.fromJson({
        'id': 'a-1',
        'body': 'aylanma matn',
        'created_at': '2026-08-22T06:14:59Z',
      });
      final restored = QuestionAnswerModel.fromJson(original.toJson());
      expect(restored.content, 'aylanma matn');
      expect(original.toJson().containsKey('content'), isFalse,
          reason: 'toJson tasodifan .insert()ga berilsa ham `content` '
              'kaliti chiqmasligi kerak');
    });
  });

  group('SOURCE GUARD — `answers.content` lib/ ga qaytib kelmaydi', () {
    // Bu guard REAL manba fayllarni o'qiydi (mock emas). Maqsad: kelajakdagi
    // refactor / "restore" jimgina PGRST204 ni qaytarib kelmasin.
    late final Directory libDir;
    late final List<File> dartFiles;

    setUpAll(() {
      libDir = Directory('lib');
      dartFiles = libDir.existsSync()
          ? libDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .toList()
          : <File>[];
    });

    test('guard haqiqatan lib/ ni o\'qiydi (jimgina pass BO\'LMASIN)', () {
      expect(libDir.existsSync(), isTrue,
          reason: 'test cwd paket root bo\'lishi kerak; lib/ topilmasa '
              'quyidagi guardlar hech narsani qo\'riqlamaydi');
      expect(dartFiles.length, greaterThan(100),
          reason: 'skanerlash ishlayotganini tasdiqlash');
    });

    test('hech bir `answers` so\'rovi `content` ustunini NOMLAMAYDI', () {
      final sources = <String, String>{
        for (final file in dartFiles) file.path: file.readAsStringSync(),
      };

      expect(findAnswerContentOffenders(sources), isEmpty,
          reason: 'live `answers` jadvalida `content` ustuni YO\'Q: '
              'select\'da 42703, insert\'da PGRST204 beradi');
    });

    test('DETEKTOR HAQIQATAN ISHLAYDI — eski buzuq kod ushlanadi', () {
      // Bu aynan device'da PGRST204 bergan ESKI kod (git tarixidan).
      const broken = '''
        final inserted = await supabaseClient.from('answers').insert({
          'question_id': postId,
          'user_id': currentUserId,
          'content': sanitized,
          'is_expert_answer': isExpert,
        }).select('*').single();
      ''';
      expect(findAnswerContentOffenders({'broken.dart': broken}), hasLength(1),
          reason: 'guard fail bo\'la olmasa, u hech narsani qo\'riqlamaydi');

      // `select` orqali nomlash ham xato (42703).
      const brokenSelect = '''
        await supabaseClient.from(kAnswersTable).select('id, content');
      ''';
      expect(findAnswerContentOffenders({'s.dart': brokenSelect}), hasLength(1));

      // Hozirgi to'g'ri kod SOXTA signal bermaydi.
      const fixed = '''
        await supabaseClient.from(kAnswersTable)
            .insert(buildAnswerInsertPayload(text: sanitized))
            .select('*, profiles(full_name, role)').single();
      ''';
      expect(findAnswerContentOffenders({'ok.dart': fixed}), isEmpty);

      // Boshqa jadvalning `content` ustuni cheklovga tushmaydi
      // (live `questions.content` REAL mavjud).
      const otherTable = '''
        await supabaseClient.from('questions').select('id, content');
      ''';
      expect(findAnswerContentOffenders({'q.dart': otherTable}), isEmpty);
    });

    test('addAnswer FAQAT buildAnswerInsertPayload orqali yozadi', () {
      final source = File('lib/features/community_forum/data/datasources/'
              'community_forum_remote_datasource.dart')
          .readAsStringSync();
      expect(source.contains('buildAnswerInsertPayload('), isTrue,
          reason: 'payload qurilishi bitta tekshirilgan joyda qolishi kerak');
      expect(source.contains('canAnswerAsExpert('), isTrue,
          reason: 'ekspert huquqi REAL profiles.role dan tekshirilishi kerak');
    });

    test('datasource domain xatolarini TOZA status kodlarga map qiladi', () {
      final source = stripLineComments(
          File('lib/features/community_forum/data/datasources/'
                  'community_forum_remote_datasource.dart')
              .readAsStringSync());
      // Savollar yo'li bilan bir xil naqsh: typed `on ... catch` + `e.message`.
      // `catch (e) => e.toString()` bo'lsa SnackBar'da klass nomi ko'rinadi.
      expect(
          source.contains('on ExpertAnswerNotAuthorizedException catch'), isTrue,
          reason: 'RBAC xatosi 403 ga map qilinishi kerak');
      expect(source.contains('on AnswerContentException catch'), isTrue,
          reason: 'bo\'sh matn 422 ga map qilinishi kerak');
      expect(RegExp(r'statusCode:\s*403').hasMatch(source), isTrue);
    });

    test('model matnni readAnswerText orqali o\'qiydi', () {
      final source = stripLineComments(
          File('lib/features/community_forum/data/models/'
                  'question_answer_model.dart')
              .readAsStringSync());
      expect(source.contains('readAnswerText('), isTrue);
      expect(RegExp(r"""json\[\s*['"]content['"]\s*\]""").hasMatch(source),
          isFalse,
          reason: 'eski bug: live qatorida `content` yo\'q -> har doim \'\'');
    });

    test('ekspert javob UI\'si role tekshiruvi bilan gate qilingan', () {
      final source = File('lib/features/community_forum/presentation/pages/'
              'question_detail_page.dart')
          .readAsStringSync();
      expect(source.contains('canAnswerAsExpert('), isTrue,
          reason: 'P0: "Advokat sifatida javob berish" chip har kimga '
              'ko\'rinsa, citizen ham ekspert javobi yuborishga urinadi');
      expect(source.contains('_canAnswerAsExpert'), isTrue);
    });

    test('client SOXTA `legal_references` iqtibosini qo\'shmaydi', () {
      final source = stripLineComments(
          File('lib/features/community_forum/data/datasources/'
                  'community_forum_remote_datasource.dart')
              .readAsStringSync());
      expect(source.contains('Lex.uz rasmiy qonunchilik normasi'), isFalse,
          reason: 'huquqiy ilovada o\'ylab topilgan iqtibos = jiddiy xato');
    });
  });
}

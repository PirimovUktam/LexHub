/// FAVQULODDA HOLAT KLASSIFIKATORI — QULF.
///
/// NUQSON (o'lchangan, `flutter test` da takrorlanadi): `tekshiruv` YOLG'IZ
/// O'ZI jinoyat-protsessual tintuv belgisi hisoblanardi. Ya'ni
///   "Soliq inspeksiyasi kameral tekshiruv o'tkazib qo'shimcha soliq
///    hisoblab chiqardi"
/// so'rovi Miranda qoidasi + 1002 ishonch telefoni bilan "FAVQULODDA HUQUQIY
/// XAVF" bannerini ochardi. Ikkinchi nuqson — `organ` substring'i: o'zbek
/// huquqiy tilidagi eng neytral so'z ("vakolatli organ", "soliq organiga")
/// so'roq majburlash belgisi deb qabul qilinardi.
///
/// Bu fayl UCH narsani qulflaydi:
///   1. TRUE POSITIVE saqlanadi — mavjud ikkita integratsiya scenariysi
///      (`legal_rag_pipeline_test.dart:38`,
///      `real_supabase_legal_rag_verification_test.dart:215`) matnlari AYNAN
///      shu yerda ham tekshiriladi, ya'ni himoya kuchsizlanmagani o'lchanadi.
///   2. FALSE POSITIVE qaytmaydi — neytral tekshiruv/ko'rik so'rovlari.
///   3. ASIMMETRIYA — jinoyat konteksti neytral kontekstdan USTUN, ya'ni
///      "Uyimda soliq xodimlari tintuv o'tkazdi" bostirilmaydi.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/emergency_detector.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart';

void main() {
  bool fires(String q) => EmergencyDetector.classify(q).isEmergency;

  group('TRUE POSITIVE — himoya KUCHSIZLANMAGAN', () {
    test('mavjud scenariy 1: ushlab turish + majburiy so\'roq', () {
      // `legal_rag_pipeline_test.dart:38` bilan AYNI matn.
      const q = "Meni ichki ishlar bo'limida ushlab turishibdi va majburiy "
          "so'roq qilishyapti";
      final s = EmergencyDetector.classify(q);
      expect(s.isEmergency, isTrue);
      expect(s.triggers, contains(EmergencyTrigger.arrest));
      expect(s.triggers, contains(EmergencyTrigger.coercedInterrogation));
    });

    test('mavjud scenariy 2: advokatsiz majburiy so\'roq + qamab qo\'yish', () {
      // `real_supabase_legal_rag_verification_test.dart:215` bilan AYNI matn.
      const q = "Meni ichki ishlar xodimlari advokatsiz majburiy so'roq "
          "qilishmoqda va qamab qo'yish bilan qo'rqitishyapti";
      final s = EmergencyDetector.classify(q);
      expect(s.isEmergency, isTrue);
      expect(s.triggers, contains(EmergencyTrigger.coercedInterrogation));
      // `qamab` ALOHIDA atama: "qamab qo'yish" `qamash` substring'iga
      // TUSHMAYDI, ya'ni bu ilgari faqat so'roq orqali ushlanardi.
      expect(s.triggers, contains(EmergencyTrigger.arrest));
    });

    test('kuchli atamalar kontekstsiz ham ishlaydi', () {
      for (final q in <String>[
        "Uyimda tintuv o'tkazishmoqda",
        'Mol-mulkim musodara qilindi',
        'Meni hibsga olishdi',
        "Ushlab turishibdi, advokat bermayapti",
        "Menga zo'ravonlik qilishdi",
        'Kaltaklashdi',
      ]) {
        expect(fires(q), isTrue, reason: 'himoya tushib qoldi: "$q"');
      }
    });

    test('kuchsiz atama + jinoyat konteksti = FAVQULODDA', () {
      for (final q in <String>[
        "Militsiya uyimni tekshirishga keldi",
        'Tergov bo\'yicha avtomobilim tekshiruvi o\'tkazildi',
        "Prokuratura reyd o'tkazdi",
        "Jinoyat ishi bo'yicha shaxsiy ko'rik qilindi",
      ]) {
        expect(fires(q), isTrue, reason: 'kontekst tan olinmadi: "$q"');
      }
    });
  });

  group('FALSE POSITIVE — o\'lchangan nuqson QAYTMAYDI', () {
    test('soliq kameral tekshiruvi Miranda qoidasini OCHMAYDI', () {
      const q = 'Soliq inspeksiyasi kameral tekshiruv o\'tkazib qo\'shimcha '
          'soliq hisoblab chiqardi';
      final s = EmergencyDetector.classify(q);
      expect(s.isEmergency, isFalse,
          reason: 'soliq tekshiruvi favqulodda huquqiy xavf EMAS');
      expect(s.wasSuppressed, isTrue,
          reason: 'atama umuman ko\'rilmasa, kelgusi regressiya sezilmaydi');
      expect(s.suppressedTerm, 'tekshiruv');
      expect(s.suppressedBy, isNotNull,
          reason: 'bostirish sababi (neytral kontekst) yozilmagan');
    });

    test('neytral tekshiruv/ko\'rik so\'rovlari bannersiz', () {
      for (final q in <String>[
        'Tibbiy ko\'rikdan o\'tish tartibi qanday?',
        'Avtomobil texnik ko\'rigi qancha turadi?',
        'Bojxona tekshiruvi qancha davom etadi?',
        'Buxgalteriya hisoboti auditi majburiymi?',
        'Mahsulot sifat ekspertizasi tekshiruvi qanday o\'tadi?',
      ]) {
        expect(fires(q), isFalse, reason: 'yolg\'on favqulodda: "$q"');
      }
    });

    test('`organ` YOLG\'IZ O\'ZI so\'roq majburlash BELGISI emas', () {
      // Bu matn bizning O'Z qamrov darvozasi javobimizdan: uni foydalanuvchi
      // qayta so'rov sifatida yozsa, banner ochilmasligi kerak.
      expect(fires('Muddat va tartibni vakolatli organdan aniqlang'), isFalse);
      expect(fires('Soliq organiga majburiy hisobot topshirish tartibi'),
          isFalse,
          reason: '`organ` + `majburiy` yana bannerni ochmoqda');
      expect(fires('Davlat organlari majburiy sug\'urta talab qiladimi?'),
          isFalse);
    });
  });

  test('ASIMMETRIYA — jinoyat konteksti neytraldan USTUN', () {
    // Aralash so'rov: `soliq` (neytral) VA `uyimda` (jinoyat) birga.
    // Bostirish YO'Q — false negative false positive'dan qimmatroq.
    final s = EmergencyDetector.classify(
      "Uyimda soliq xodimlari bilan militsiya tekshiruv o'tkazdi",
    );
    expect(s.isEmergency, isTrue);
    expect(s.suppressedTerm, isNull);
  });

  test('bo\'sh va qamrovsiz so\'rov — bannersiz, xatosiz', () {
    for (final q in <String>['', '   ', 'Salom', 'Aliment qanday hisoblanadi?']) {
      expect(fires(q), isFalse);
    }
  });

  test('natija DETERMINISTIK', () {
    const q = "Militsiya uyimni tekshirishga keldi";
    expect(EmergencyDetector.classify(q).triggers,
        EmergencyDetector.classify(q).triggers);
  });

  group('ULANISH — datasource AYNI klassifikatordan foydalanadi', () {
    test('protokol matni true positive\'da to\'liq qaytadi', () async {
      final ds = LegalAssistantRemoteDataSourceImpl();
      final p = await ds.detectEmergency(
        "Meni ichki ishlar bo'limida ushlab turishibdi va majburiy so'roq "
        "qilishyapti",
      );
      expect(p, isNotNull);
      expect(p!.isEmergency, isTrue);
      expect(p.emergencyHotline, '1002');
      expect(
          p.constitutionalRights
              .any((r) => r.contains('28-moddasi (Miranda qoidasi)')),
          isTrue);
      expect(p.constitutionalRights.any((r) => r.contains('29-moddasi')),
          isTrue);
    });

    test('soliq tekshiruvida datasource `null` qaytaradi', () async {
      final ds = LegalAssistantRemoteDataSourceImpl();
      expect(
        await ds.detectEmergency('Soliq inspeksiyasi kameral tekshiruv '
            'o\'tkazib qo\'shimcha soliq hisoblab chiqardi'),
        isNull,
        reason: 'datasource yana o\'z substring mantiqiga qaytgan',
      );
    });
  });
}

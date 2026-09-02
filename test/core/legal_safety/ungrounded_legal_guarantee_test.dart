// LexHub — MANBASIZ HUQUQIY KAFOLAT QULFI.
//
// NIMA UCHUN BU FAYL BOR (o'lchangan nuqson, 2026-08-30): community oqimida
// IKKI joyda qattiq yozilgan matn foydalanuvchiga "Fuqaroning huquqlari
// qonunchilik bilan kafolatlangan" deb aytardi va bu gap
// `questions.ai_summary` ustuni orqali BAZAGA saqlanardi:
//   * `community_forum_remote_datasource.dart:434` (bazaga YOZARDI)
//   * `ask_community_dialog.dart:202` (optimistik postda KO'RSATARDI)
// Birorta modda keltirilmagan, ya'ni bu ASOSSIZ huquqiy kafolat edi
// (`.claude/skills/lexhub-legal-answer-safety` §1 taqiqlangan iboralar, §3
// modda darajasidagi grounding). Ikki nusxa allaqachon bir-biridan ajralib
// ketgan edi ("amaldagi" so'zi faqat bittasida bor edi) — shuning uchun matn
// `CommunityPost.categoryRoutingNote` da YAGONA manbaga ko'chirildi va
// kafolat gapi OLIB TASHLANDI.
//
// BU TEST NIMANI USHLAYDI: `lib/` ga YANGI absolut kafolat qo'shilishini.
// Uslub ataylab `test/l10n/no_hardcoded_ui_strings_test.dart` ZONA B bilan
// bir xil — HAR BIR fayl uchun ANIQ son qulflanadi. Son o'ssa ham, kamaysa
// ham test yiqiladi, ya'ni ro'yxat eskirmaydi va "kamaytirib qutulish" ham
// jim o'tmaydi.
//
// IZOHLAR HISOBGA OLINMAYDI (ataylab): `//` bilan boshlanadigan va satr
// oxiridagi izohlar foydalanuvchiga YETIB BORMAYDI, va repo'da olib
// tashlangan matnni HUJJATLASHTIRGAN izohlar bor. Ularni sanash bu testni
// o'z izohlariga qarshi qo'yardi.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/legal_absolutes.dart';

/// Taqiqlangan absolyut iboralar — YAGONA MANBA
/// `test/support/legal_absolutes.dart` da (uni EKRAN darajasidagi widget
/// testlar ham ishlatadi).
///
/// NAQSH 2026-08-30 DA KENGAYTIRILDI: ilgari u faqat `100% to'g'ri` ni
/// bilardi va `emergency_rights_page.dart:40` dagi "100% qonuniy haqlisiz"
/// ni O'TKAZIB YUBORARDI (o'lchandi — shu satr bu testda ko'rinmagan holda
/// prod kodda turgan edi). Endi `100% + huquqiy sifat` birikmasi ushlanadi.
final _forbidden = forbiddenLegalAbsolutes;

/// QULFLANGAN INVENTAR — 2026-08-30 da o'lchangan va QO'LDA ko'rilgan.
/// Har bir qoldiq ASOSLI: gapning O'ZIDA yoki yonida manba (modda/kodeks/
/// Konstitutsiya) keltirilgan.
const _locked = <String, int>{
  // `:49` — "... kafolatlangan (Konstitutsiya 28-modda - Miranda qoidasi)."
  // Modda AYNAN keltirilgan.
  'lib/core/legal_safety/master_system_prompt.dart': 1,
  // `:42` — Konstitutsiyaviy yuridik yordam huquqi. Grounding qo'shni
  // maydonlarda (bilim bazasi yozuvi manba bilan birga saqlanadi).
  'lib/core/legal_safety/uzbek_legal_knowledge_base.dart': 1,
  // `:503` — "... Mehnat kodeksiga ko'ra ... kafolatlangan" (kodeks nomi bor);
  // `:549` — "... Konstitutsiya bilan kafolatlangan" (manba bor).
  'lib/features/legal_assistant/data/datasources/'
      'legal_assistant_remote_datasource.dart': 2,
};

/// `//` izohlarini olib tashlaydi. String literal ichidagi `//` (masalan URL)
/// noto'g'ri qirqilmasligi uchun qo'shtirnoq holati kuzatiladi.
String _stripComment(String line) {
  var inSingle = false;
  var inDouble = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == r'\') {
      i++;
      continue;
    }
    if (c == "'" && !inDouble) inSingle = !inSingle;
    if (c == '"' && !inSingle) inDouble = !inDouble;
    if (c == '/' && !inSingle && !inDouble && i + 1 < line.length &&
        line[i + 1] == '/') {
      return line.substring(0, i);
    }
  }
  return line;
}

void main() {
  test('lib/ da faqat QULFLANGAN va manbasi bor kafolat iboralari qoladi', () {
    final found = <String, List<int>>{};

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.replaceAll(r'\', '/');
      if (rel.contains('lib/l10n/gen/')) continue; // generatsiya qilingan

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_forbidden.hasMatch(_stripComment(lines[i]))) {
          found.putIfAbsent(rel, () => <int>[]).add(i + 1);
        }
      }
    }

    final actual = {
      for (final e in found.entries) e.key: e.value.length,
    };

    expect(
      actual,
      _locked,
      reason: 'MANBASIZ HUQUQIY KAFOLAT QULFI buzildi.\n'
          'Topildi: $found\n'
          'Qulflangan: $_locked\n\n'
          'SON O\'SDI bo\'lsa: yangi absolut kafolat qo\'shilgan. '
          '`lexhub-legal-answer-safety` §1 bo\'yicha uni defensible '
          'so\'zlashga almashtir ("hozirgi ma\'lumotga ko\'ra", '
          '"bu huquqiy maslahat emas") yoki modda keltir (§3).\n'
          'SON KAMAYDI bo\'lsa: matn o\'zgargan — yuqoridagi inventarni '
          'YANGI o\'lchov bilan yangila, izohdagi sababni ham yoz.',
    );
  });

  test('olib tashlangan kafolat gapi QAYTIB kelmadi', () {
    final suspects = <String>[
      'lib/features/community_forum/data/datasources/'
          'community_forum_remote_datasource.dart',
      'lib/features/community_forum/presentation/widgets/'
          'ask_community_dialog.dart',
      'lib/features/community_forum/domain/entities/community_post.dart',
    ];

    for (final path in suspects) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path yo\'q');
      // Faqat KOD satrlari: izohlarda nuqson ATAYLAB hujjatlashtirilgan.
      final code =
          file.readAsLinesSync().map(_stripComment).join('\n');
      expect(
        _forbidden.hasMatch(code),
        isFalse,
        reason: '$path ga kafolat iborasi QAYTDI. Bu matn 2026-08-30 da '
            'ataylab olib tashlangan: u modda keltirmasdan "huquqlari '
            'kafolatlangan" deb da\'vo qilardi va `questions.ai_summary` '
            'orqali BAZAGA saqlanardi.',
      );
    }
  });
}

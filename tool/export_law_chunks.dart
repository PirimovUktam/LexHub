// LexHub — `law_article_chunks` SEED EKSPORTERI.
//
// NIMA UCHUN SKRIPT, QO'LDA KO'CHIRISH EMAS: jonli bazaga yuboriladigan modda
// MATNI repodagi kurirlangan bilan BAYT-BAYT bir xil bo'lishi shart. Qo'lda
// ko'chirilsa apostrof/qo'shtirnoq yoki bir so'z tushib qolishi mumkin — bu
// esa "to'qilgan huquqiy matn" degani. Shuning uchun manba yagona:
// `UzbekLegalKnowledgeBase.verifiedLawChunks`.
//
// ISHLATISH:
//   dart run tool/export_law_chunks.dart > <fayl>.json
//
// Chiqish — PostgREST `POST /rest/v1/law_article_chunks` uchun tayyor massiv.
// `embedding` ATAYLAB yuborilmaydi: u nullable va bu seed vector qidiruvni
// emas, matn/`article_number` bo'yicha qidiruvni tiriltiradi.

import 'dart:convert';
import 'dart:io';

import 'package:lexhub/core/legal_safety/uzbek_legal_knowledge_base.dart';

void main() {
  final rows = UzbekLegalKnowledgeBase.verifiedLawChunks
      .map((c) => c.toJson())
      .toList(growable: false);
  stdout.write(const JsonEncoder.withIndent('  ').convert(rows));
}

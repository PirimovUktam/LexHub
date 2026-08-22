// LexHub — `buildQuestionInsertPayload` chiqishini AYNAN chop etadi.
//
// Hisobotdagi "NEW PAYLOAD" bo'limi qo'lda yozilgan da'vo emas, balki shu
// skript chiqargan haqiqiy JSON bo'lishi uchun kerak.
//
// Ishga tushirish:  dart run tool/print_question_payload.dart
//
// Bu CLI diagnostika skripti — chiqish stdout'ga yoziladi.
// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:lexhub/features/community_forum/data/datasources/question_category_resolver.dart';

void main() {
  const encoder = JsonEncoder.withIndent('  ');

  print('--- 1. NORMAL HOLAT (Mehnat huquqi) ---');
  final ok = buildQuestionInsertPayload(
    userId: '11111111-2222-4333-8444-555555555555',
    title: 'Dam olish kunida majburiy ishlash',
    description: "Rahbar yakshanba kuni ishga chiqishni talab qilmoqda. "
        "Bu qonuniymi?",
    aiSummary: "Ushbu savol Mehnat huquqi doirasida ko'rib chiqiladi.",
    isAnonymous: true,
    categoryId: '9e25aeac-a6e0-4e0f-8262-02b06a714f42',
  );
  print(encoder.convert(ok));
  print('body kaliti mavjud       : ${ok.containsKey('body')}');
  print('body != null             : ${ok['body'] != null}');
  print('body.trim().isNotEmpty   : ${(ok['body'] as String).trim().isNotEmpty}');
  print('matn ustunlari           : $kQuestionTextColumns');
  print('yuborilgan kalitlar (${ok.keys.length}) : ${ok.keys.toList()}');

  print('\n--- 2. BO\'SH MATN (body = "") ---');
  try {
    buildQuestionInsertPayload(
      userId: '11111111-2222-4333-8444-555555555555',
      title: 'Sarlavha bor',
      description: '',
      aiSummary: 'x',
      isAnonymous: true,
      categoryId: '9e25aeac-a6e0-4e0f-8262-02b06a714f42',
    );
    print('XATO: payload qurildi (bo\'lmasligi kerak edi)');
  } on QuestionContentException catch (e) {
    print('QuestionContentException(field=${e.field})');
    print('message: ${e.message}');
    print('HTTP so\'rov YUBORILMADI (23502 hosil bo\'lmadi)');
  }

  print('\n--- 3. FAQAT BO\'SHLIQ (body = "   ") ---');
  try {
    buildQuestionInsertPayload(
      userId: '11111111-2222-4333-8444-555555555555',
      title: 'Sarlavha bor',
      description: '   \n\t ',
      aiSummary: 'x',
      isAnonymous: true,
      categoryId: '9e25aeac-a6e0-4e0f-8262-02b06a714f42',
    );
    print('XATO: payload qurildi');
  } on QuestionContentException catch (e) {
    print('QuestionContentException(field=${e.field}) -> ${e.message}');
  }

  print('\n--- 4. DISPLAY NOM category_id sifatida (task 1 regressiya) ---');
  try {
    buildQuestionInsertPayload(
      userId: '11111111-2222-4333-8444-555555555555',
      title: 'Sarlavha',
      description: 'Matn bor',
      aiSummary: 'x',
      isAnonymous: true,
      categoryId: 'Mehnat huquqi',
    );
    print('XATO: payload qurildi');
  } on CategoryResolutionException catch (e) {
    print('CategoryResolutionException -> ${e.message}');
  }
}

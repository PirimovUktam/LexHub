/// QULF — `main` SHOXIDAN Git AVTO-DEPLOY O'CHIRILGAN BO'LISHI SHART.
///
/// O'LCHANGAN HODISA (2026-09-02): `lexhub-theta.vercel.app` `404 NOT_FOUND`
/// qaytardi. Vercel loyihasi GitHub `main` ga bog'langan edi va har push
/// 4 sekund ichida repo ILDIZIDAN Production deployment qurardi. Ildizda
/// `index.html` YO'Q (Flutter chiqishi `build/web` da, u esa gitignore'da —
/// `.gitignore:53` -> `/build/`), shuning uchun deployment BO'SH chiqardi
/// (`vercel inspect` -> `Builds: . [0ms]`) va ishlaydigan CLI
/// deployment'idan Production alias'ini TORTIB OLARDI.
///
/// To'liq zanjir va deployment/commit vaqt mosligi: `docs/DEPLOY.md`.
///
/// NIMA UCHUN QULF KERAK: `vercel.json` o'chib qolsa yoki `git` kaliti
/// olib tashlansa, keyingi `git push origin main` saytni YANA o'ldiradi va
/// buni HECH NARSA aytmaydi — nosozlik faqat brauzerda ko'rinadi.
///
/// JSON `jsonDecode` bilan PARSE qilinadi, matn sifatida `contains(...)`
/// bilan qidirilmaydi — shuning uchun bu qulf satr oxiri (CRLF/LF) sinfiga
/// KIRMAYDI (`test/support/source_lock_portability_test.dart`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vercel.json `main` uchun Git avto-deploy\'ni O\'CHIRADI', () {
    final file = File('vercel.json');
    expect(file.existsSync(), isTrue,
        reason: 'vercel.json YO\'Q — `main` ga push bo\'sh Production '
            'deployment yaratib saytni o\'ldiradi (docs/DEPLOY.md)');

    final decoded = jsonDecode(file.readAsStringSync());
    expect(decoded, isA<Map<String, dynamic>>(),
        reason: 'vercel.json JSON obyekt bo\'lishi kerak');

    final cfg = decoded as Map<String, dynamic>;
    // BO'SH TEKSHIRUV KO'RINMAS QOLMASIN: fayl bo'shab qolsa quyidagi
    // `isFalse` da'volari VAKUUM bo'lardi.
    expect(cfg, isNotEmpty, reason: 'vercel.json BO\'SH — qulf vakuum');

    final git = cfg['git'];
    expect(git, isA<Map<String, dynamic>>(),
        reason: '`git` kaliti YO\'Q — avto-deploy YOQILGAN holatga qaytdi');

    final enabled = (git as Map<String, dynamic>)['deploymentEnabled'];
    expect(enabled, isA<Map<String, dynamic>>(),
        reason: '`git.deploymentEnabled` YO\'Q');

    expect((enabled as Map<String, dynamic>)['main'], isFalse,
        reason: '`main` uchun Git deployment YOQILGAN. Repo ildizida '
            '`index.html` yo\'q, Flutter chiqishi `build/web` da va '
            'gitignore\'da — ya\'ni push BO\'SH deployment yaratib '
            'Production alias\'ini tortib oladi. Deploy yo\'li: '
            '`cd build/web && vercel deploy --prod` (docs/DEPLOY.md)');
  });
}

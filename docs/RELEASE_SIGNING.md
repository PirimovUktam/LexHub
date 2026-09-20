# Android release imzosi

Release endi debug kalitiga qaytmaydi. Signing ma’lumoti yo‘q bo‘lsa release
yig‘ish xato bilan to‘xtaydi; debug yig‘ish o‘zgarishsiz qoladi.

Ilova egasi Play Console’da ishlatiladigan upload/release kalitini taqdim etishi
kerak. Mavjud ilovani yangilash uchun avvalgi imzo siyosatiga mos kalit talab
qilinadi. Haqiqiy kalit, alias yoki parol taxmin qilinmaydi.

`android/key.properties.example` nusxasidan lokal `android/key.properties`
tayyorlang yoki quyidagi muhit o‘zgaruvchilarini CI sirlar omborida belgilang:

- `LEXHUB_ANDROID_STORE_FILE`
- `LEXHUB_ANDROID_STORE_PASSWORD`
- `LEXHUB_ANDROID_KEY_ALIAS`
- `LEXHUB_ANDROID_KEY_PASSWORD`

Muhit qiymati fayldagi qiymatdan ustun. `storeFile` mutlaq yo‘l yoki `android/`
ichiga nisbatan yo‘l bo‘lishi mumkin. Kalit va to‘ldirilgan properties fayli
Git’ga qo‘shilmaydi. Parollarni buyruq satri yoki build logiga chiqarmang.

Keyin `flutter build appbundle --release --dart-define-from-file=env/prod.json`
yoki APK kerak bo‘lsa `flutter build apk --release --dart-define-from-file=env/prod.json`
bajariladi. APK uchun Android SDK `apksigner verify --print-certs` natijasidagi
SHA-256 fingerprint’ni ilova egasining kutilgan sertifikati bilan solishtiring.

Vaqtinchalik lokal test kaliti bilan muvaffaqiyatli build production imzosi
tasdiqlanganini anglatmaydi. Production kaliti bilan build, fingerprint va
tarqatish ushbu repository konfiguratsiyasidan alohida tekshiriladi.

## Stage 1 admin release gate — 2026-09-20

- Hozir `android/key.properties` va to'rtta signing environment qiymati mavjud
  emas. Real production signing **BLOCKED**. Ushbu ishda yangi key yaratilmaydi.
- Release guard ma'lum `androiddebugkey` aliasini va `debug.keystore` fayl nomini
  (nisbiy/absolyut, Windows/Linux, katta-kichik harflardan qat'i nazar) rad etadi.
  Bu ixtiyoriy qayta nomlangan test sertifikatini aniqlash kafolati emas.
- App egasi Play App Signing ishlatilishini, upload key yoki to'g'ridan-to'g'ri
  APK signing key kerakligini aniqlasin. APK'ning cert'i bilan Play tarqatgan
  app-signing cert'i bir xil deb taxmin qilinmasin. Kutilgan sertifikat SHA-256
  qiymati egasining mustaqil, ishonchli yozuvidan olinadi.
- CI'da keystore secret-file sifatida vaqtinchalik cheklangan katalogga
  o'rnatiladi; to'rtta env faqat release jobga uzatiladi. Log masking va job
  tugagach temp keyni olib tashlash talab qilinadi. Cache/artifact ro'yxatiga
  keystore yoki to'ldirilgan properties kiritilmaydi. CI workflow hozir yo'q;
  bu konfiguratsiya yangi remote pipeline o'rnatilganini anglatmaydi.
- Builddan keyin `apksigner verify --print-certs` bilan imzo va kutilgan cert
  SHA-256 tengligi tekshiriladi. Faqat release APK/AAB artifacti va qiymatsiz
  tekshiruv xulosasi saqlanadi. Eski versiyadan update smoke va huquqlar/account
  isolation sinovi alohida staging/qurilmada bajariladi.

Kalitsiz buildning rad etilishi hamda debug konfiguratsiyali buildning
`Debug signing is not permitted` bilan rad etilishi lokal negative evidence;
ular haqiqiy production key bilan muvaffaqiyatli build o'rnini bosmaydi.

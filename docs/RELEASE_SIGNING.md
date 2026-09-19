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

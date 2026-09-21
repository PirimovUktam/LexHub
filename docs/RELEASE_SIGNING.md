# Android release signing

Release build debug kalitiga qaytmaydi. Signing ma'lumoti yetishmasa yoki
ma'lum debug keystore/alias berilsa build to'xtaydi. Bu qayta nomlangan har
qanday test kalitini aniqlash yoki haqiqiy production certni tasdiqlash emas.

## Kerakli material

Release owner mavjud ilovaning Play App Signing modelini aniqlaydi:
AAB upload key va Play app-signing key bir xil bo'lishi shart emas.
Keystore, alias, store/key password hamda shu artifact uchun mustaqil
ishonchli certificate SHA-256 kerak. Ularni taxminan yaratish mumkin emas.

`android/key.properties.example`dan ignored `android/key.properties`
yaratish yoki release processiga quyidagilarni secret manager orqali berish mumkin:

- `LEXHUB_ANDROID_STORE_FILE`
- `LEXHUB_ANDROID_STORE_PASSWORD`
- `LEXHUB_ANDROID_KEY_ALIAS`
- `LEXHUB_ANDROID_KEY_PASSWORD`

Environment qiymatlari properties faylidan ustun. `storeFile` absolute yoki
`android/`ga nisbatan path bo'lishi mumkin. Private key/password repository,
client config, command line, cache yoki logga yozilmaydi. CI'dagi vaqtinchalik
keystore faqat release jobga ochiladi va job yakunida olib tashlanadi.

## Build va verification

```sh
flutter build apk --release --dart-define-from-file=env/prod.json
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Ikkala command exit code 0 bo'lsin. Signer certificate SHA-256ni release owner
bergan kutilgan cert bilan solishtiring; faqat match/statusni public natijaga
kiriting. Oldingi versiyadan update va account isolation smoke ham bajariladi.

Play uchun `flutter build appbundle --release --dart-define-from-file=env/prod.json`
ishlatiladi; `apksigner` AAB verification vositasi emas. Upload, Play release va
Vercel web deploy mustaqil amallar. Lokal test key bilan build yoki missing-key
guard testi production signing isboti emas.

[Build testlari](TESTING.md) | [Web release](DEPLOY.md)

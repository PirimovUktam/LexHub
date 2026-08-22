import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';

abstract class CitizenServicesLocalDataSource {
  Future<List<CitizenService>> getServices({String? category, String? searchQuery});
  Future<CitizenService> getServiceById(String serviceId);
}

class CitizenServicesLocalDataSourceImpl implements CitizenServicesLocalDataSource {
  static final List<CitizenService> _verifiedServices = [
    CitizenService(
      id: 'service_traffic_discount',
      title: "YHQ jarimalariga 50% chegirma olish va shikoyat berish",
      category: "Yo'l harakati",
      department: "IIV Yo'l harakati xavfsizligi xizmati",
      description: "Radar yoki inspektor tomonidan yozilgan ma'muriy jarimani 15 kun ichida to'lab 50% chegirmadan foydalanish yoki 10 kun ichida shikoyat qilish tartibi.",
      isFree: true,
      costBhmPercent: 0.0,
      processingDays: 10,
      requiredDocuments: const [
        "Jarima to'g'risidagi qaror raqami",
        "Haydovchilik guvohnomasi yoki Tex-pasport",
        "Radar joylashuviga e'tiroz dalillari (agar shikoyat qilinsa)",
      ],
      onlineUrl: "https://my.gov.uz/uz/service/469",
      deadlineLawReference: "MJtK 332-1-modda (50% chegirma 15 kunda) va 315-modda (shikoyat 10 kunda)",
      sourceUrl: "https://lex.uz/docs/97661#1184234",
      legalBasis: "O'zbekiston Respublikasining Ma'muriy javobgarlik to'g'risidagi kodeksi 332-1-moddasi",
      lastVerifiedAt: DateTime(2026, 1, 15),
      status: 'active',
      isPopular: true,
      steps: const [
        ServiceStep(
          stepNumber: 1,
          title: "Qaror bilan tanishish",
          description: "my.gov.uz yoki YHXX rasmiy boti orqali qoidabuzarlik fotosurati va radar sertifikatini tekshiring.",
          actionUrl: "https://my.gov.uz/uz/service/469",
          stepType: 'online',
        ),
        ServiceStep(
          stepNumber: 2,
          title: "50% chegirma bilan to'lash",
          description: "Qaror chiqarilgan kundan boshlab 15 kun ichida jarimaning 50% qismini to'lang (Payme, Click yoki bank orqali).",
          warningNote: "15 kun o'tgach jarima to'liq 100% miqdorda undiriladi.",
          actionUrl: "https://payme.uz",
          stepType: 'payment',
        ),
        ServiceStep(
          stepNumber: 3,
          title: "Norozilik bo'lsa shikoyat arizasi",
          description: "Qaror nusxasi topshirilgan kundan boshlab 10 kun ichida tuman ma'muriy sudiga ariza bering.",
          warningNote: "10 kunlik muddat o'tkazilsa, faqat uzrli sabablar bilan sud tomonidan tiklanadi.",
          stepType: 'appeal',
        ),
      ],
    ),
    CitizenService(
      id: 'service_labor_complaint',
      title: "Noqonuniy ishdan bo'shatish yoki ish haqi bo'yicha shikoyat",
      category: "Mehnat huquqi",
      department: "Kambag'allikni qisqartirish va bandlik vazirligi (Davlat mehnat inspeksiyasi)",
      description: "Ish beruvchi tomonidan ish haqi to'lanmaganligi, noqonuniy bo'shatilganligi yoki majburiy mehnatga jalb etilganligi bo'yicha rasmiy tekshiruv talab qilish.",
      isFree: true,
      costBhmPercent: 0.0,
      processingDays: 15,
      requiredDocuments: const [
        "Mehnat shartnomasi va buyruq nusxasi (mavjud bo'lsa)",
        "Bank hisobvarag'idan ko'chirma (oylik tushmaganligi bo'yicha)",
        "Ish beruvchiga berilgan yozma ariza nusxasi",
      ],
      onlineUrl: "https://my.gov.uz/uz/service/523",
      deadlineLawReference: "Mehnat kodeksi 560-modda (Sudga da'vo muddati: 1 oy)",
      sourceUrl: "https://lex.uz/docs/6257288#6273110",
      legalBasis: "O'zbekiston Respublikasining Mehnat kodeksi 560-moddasi",
      lastVerifiedAt: DateTime(2026, 1, 10),
      status: 'active',
      isPopular: true,
      steps: const [
        ServiceStep(
          stepNumber: 1,
          title: "Pretenziya berish",
          description: "Ish beruvchiga 2 nusxada yozma ogohlantirish arizasi topshiring.",
          stepType: 'offline',
        ),
        ServiceStep(
          stepNumber: 2,
          title: "Davlat mehnat inspeksiyasiga murojaat",
          description: "my.gov.uz portali orqali yoki 1176 ishonch telefoniga rasmiy shikoyat yuboring.",
          actionUrl: "https://my.gov.uz/uz/service/523",
          stepType: 'online',
        ),
        ServiceStep(
          stepNumber: 3,
          title: "Sudga da'vo kiritish",
          description: "Ishdan bo'shatish to'g'risidagi buyruq chiqqan kundan boshlab 1 oy ichida fuqarolik sudiga da'vo bering. Ishchi xodimlar sud bojidan ozod qilinadi!",
          warningNote: "1 oylik da'vo muddati o'tkazib yuborilsa, sud arizani rad etishi mumkin.",
          stepType: 'appeal',
        ),
      ],
    ),
    CitizenService(
      id: 'service_child_subsidy',
      title: "Bolalar nafaqasi va moddiy yordam tayinlash (Yagona reestr)",
      category: "Ijtimoiy himoya",
      department: "Ijtimoiy himoya milliy agentligi",
      description: "Kam ta'minlangan oilalarga bolalar nafaqasi va moddiy yordam tayinlash bo'yicha 'Ijtimoiy himoya yagona reestri' orqali ariza topshirish.",
      isFree: true,
      costBhmPercent: 0.0,
      processingDays: 7,
      requiredDocuments: const [
        "Ariza beruvchi va oila a'zolarining JSHSHIR (PINFL) raqamlari",
        "Bolalarning tug'ilganlik haqidagi guvohnomalari",
      ],
      onlineUrl: "https://my.gov.uz/uz/service/670",
      deadlineLawReference: "Vazirlar Mahkamasining 654-son qarori",
      sourceUrl: "https://lex.uz/docs/5688536",
      legalBasis: "Vazirlar Mahkamasining 2021-yil 21-oktabrdagi 654-son qarori",
      lastVerifiedAt: DateTime(2026, 2, 1),
      status: 'active',
      isPopular: true,
      steps: const [
        ServiceStep(
          stepNumber: 1,
          title: "Daromad mezonini baholash",
          description: "Oilaning har bir a'zosiga to'g'ri keladigan oylik daromad minimal iste'mol xarajatlaridan oshmasligi shart.",
          stepType: 'online',
        ),
        ServiceStep(
          stepNumber: 2,
          title: "my.gov.uz orqali ariza yuborish",
          description: "OneID orqali tizimga kirib, oila a'zolarini ko'rsatgan holda elektron ariza yuboring.",
          actionUrl: "https://my.gov.uz/uz/service/670",
          stepType: 'online',
        ),
      ],
    ),
    CitizenService(
      id: 'service_consumer_refund',
      title: "Nuqsonli tovarni almashtirish va pulni qaytarish",
      category: "Iste'molchi huquqi",
      department: "Raqobatni rivojlantirish va iste'molchilar huquqlarini himoya qilish qo'mitasi",
      description: "Xarid qilingan sifatsiz tovar uchun sotuvchidan pulni qaytarib olish yoki kafolat bo'yicha bepul ta'mirlash tartibi.",
      isFree: true,
      costBhmPercent: 0.0,
      processingDays: 10,
      requiredDocuments: const [
        "Tovar cheki, kvitansiya yoki elektron to'lov kodi",
        "Kafolat taloni (mavjud bo'lsa)",
        "Sotuvchiga yozilgan pretenziya nusxasi",
      ],
      onlineUrl: "https://consumer.gov.uz",
      deadlineLawReference: "Iste'molchilar huquqlarini himoya qilish to'g'risidagi Qonun 18-modda (10 kun)",
      sourceUrl: "https://lex.uz/docs/44265#44389",
      legalBasis: "O'zbekiston Respublikasining 'Iste'molchilarning huquqlarini himoya qilish to'g'risida'gi Qonuni 18-moddasi",
      lastVerifiedAt: DateTime(2026, 1, 20),
      status: 'active',
      isPopular: false,
      steps: const [
        ServiceStep(
          stepNumber: 1,
          title: "Sotuvchiga tovar va chek bilan murojaat",
          description: "Xarid qilingan kundan boshlab 10 kun ichida tovar ko'rinishi saqlangan holda sotuvchiga murojaat qiling.",
          stepType: 'offline',
        ),
        ServiceStep(
          stepNumber: 2,
          title: "1159 raqamiga shikoyat",
          description: "Agar sotuvchi rad etsa, Iste'molchilar huquqlarini himoya qilish agentligiga 1159 orqali xabar qiling.",
          actionUrl: "https://consumer.gov.uz",
          stepType: 'appeal',
        ),
      ],
    ),
    CitizenService(
      id: 'service_cadastre_extract',
      title: "Ko'chmas mulk kadastr pasportini rasmiylashtirish va ko'chirma olish",
      category: "Kadastr va Uy-joy",
      department: "Davlat kadastrlari palatasi",
      description: "Uy, yer yoki kvartira uchun kadastr pasportini shakllantirish, mulk huquqini davlat ro'yxatidan o'tkazish.",
      isFree: false,
      costBhmPercent: 1.25,
      processingDays: 5,
      requiredDocuments: const [
        "Mulkka egalik huquqini tasdiqlovchi hujjat (shartnoma, order, meros)",
        "Egasining pasport / ID karta nusxasi",
      ],
      onlineUrl: "https://my.gov.uz/uz/service/101",
      deadlineLawReference: "Vazirlar Mahkamasining 535-son qarori",
      sourceUrl: "https://lex.uz/docs/4977467",
      legalBasis: "Vazirlar Mahkamasining 2020-yil 2-sentabrdagi 535-son qarori",
      lastVerifiedAt: DateTime(2026, 1, 18),
      status: 'active',
      isPopular: false,
      steps: const [
        ServiceStep(
          stepNumber: 1,
          title: "Arizani elektron topshirish",
          description: "my.gov.uz orqali kadastr obyekti manzilini kiritib ariza yuboring.",
          actionUrl: "https://my.gov.uz/uz/service/101",
          stepType: 'online',
        ),
        ServiceStep(
          stepNumber: 2,
          title: "Mutaxassis o'lchov o'tkazishi",
          description: "Kadastr xodimi kelib obyektni o'lchaydi va elektron pasport yaratadi.",
          stepType: 'offline',
        ),
      ],
    ),
    CitizenService(
      id: 'service_notary_power_of_attorney',
      title: "Elektron notarius orqali ishonchnoma (Doverennost) rasmiylashtirish",
      category: "Iste'molchi huquqi",
      department: "Adliya vazirligi (E-Notarius)",
      description: "Avtotransport vositasini boshqarish yoki mulkni tasarruf etish bo'yicha videoaloqa orqali uydan chiqmasdan notarial tasdiqlangan elektron ishonchnoma berish.",
      isFree: false,
      costBhmPercent: 0.50,
      processingDays: 1,
      requiredDocuments: const [
        "Mulk egasi va ishonchli shaxsning ID karta / Pasport ma'lumotlari",
        "Tex-pasport yoki mulk hujjati",
        "OneID biometrik tasdiq",
      ],
      onlineUrl: "https://e-notarius.uz",
      deadlineLawReference: "'Notariat to'g'risida'gi Qonun va VMQ-741-son qarori",
      sourceUrl: "https://lex.uz/docs/5110594",
      legalBasis: "Vazirlar Mahkamasining 2020-yil 18-noyabrdagi 741-son qarori",
      lastVerifiedAt: DateTime(2026, 2, 5),
      status: 'active',
      isPopular: true,
      steps: const [
        ServiceStep(
          stepNumber: 1,
          title: "E-Notarius portaliga kirish va ariza to'ldirish",
          description: "e-notarius.uz portaliga OneID orqali kiring, ishonchnoma turini tanlang va ishonchli shaxs ma'lumotlarini kiriting.",
          actionUrl: "https://e-notarius.uz",
          stepType: 'online',
        ),
        ServiceStep(
          stepNumber: 2,
          title: "Videoaloqa orqali notarius bilan tasdiqlash",
          description: "Belgilangan vaqtda notarius bilan videoaloqaga chiqing, shaxsingizni tasdiqlang va elektron imzo bilan hujjatni imzolang.",
          warningNote: "Elektron ishonchnoma qog'oz nusxasi bilan bir xil yuridik kuchga ega (QR-kod orqali tekshiriladi).",
          actionUrl: "https://e-notarius.uz",
          stepType: 'online',
        ),
      ],
    ),
  ];

  @override
  Future<List<CitizenService>> getServices({String? category, String? searchQuery}) async {
    var list = List<CitizenService>.from(_verifiedServices);

    if (category != null && category != 'Barchasi') {
      list = list.where((s) => s.category.toLowerCase() == category.toLowerCase()).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list
          .where((s) =>
              s.title.toLowerCase().contains(q) ||
              s.description.toLowerCase().contains(q) ||
              s.department.toLowerCase().contains(q) ||
              (s.legalBasis?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return list;
  }

  @override
  Future<CitizenService> getServiceById(String serviceId) async {
    return _verifiedServices.firstWhere(
      (s) => s.id == serviceId,
      orElse: () => _verifiedServices.first,
    );
  }
}

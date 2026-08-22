import 'package:flutter/material.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_form_field.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';

abstract class DocumentTemplatesDataSource {
  Future<List<DocumentTemplate>> getTemplates({String? category});
  Future<DocumentTemplate> getTemplateById(String id);
}

class DocumentTemplatesDataSourceImpl implements DocumentTemplatesDataSource {
  static final List<DocumentTemplate> _templates = [
    // 1. Iste'molchi huquqlari
    const DocumentTemplate(
      id: 'template_consumer_refund',
      title: "Sifatsiz tovar uchun pulni qaytarish talabnomasi",
      category: "Iste'molchi huquqlari",
      legalBasisSummary: "Iste'molchilar huquqlarini himoya qilish to'g'risidagi Qonun 13, 18-moddalari",
      description: "Nuqsonli yoki sifatsiz tovar sotib olganda sotuvchiga pulni to'liq qaytarishni talab qiluvchi rasmiy da'vo arizasi.",
      icon: Icons.shopping_bag_outlined,
      color: AppColors.emerald,
      fields: [
        DocumentFormField(
          id: 'store_name',
          label: "Do'kon yoki sotuvchi nomi (MCHJ/YATT)",
          placeholder: "Masalan: 'MediaPark' do'koni ma'muriyatiga",
        ),
        DocumentFormField(
          id: 'applicant_name',
          label: "Foydalanuvchi (Ariza beruvchi) F.I.Sh",
          placeholder: "Masalan: Karimov Anvar Jasurovich",
        ),
        DocumentFormField(
          id: 'applicant_address',
          label: "Yashash manzili va telefon raqami",
          placeholder: "Masalan: Toshkent sh., Chilonzor t., 12-uy, +998901234567",
        ),
        DocumentFormField(
          id: 'purchase_date',
          label: "Tovar xarid qilingan sana",
          placeholder: "Masalan: 12.08.2026",
          fieldType: DocumentFieldType.date,
        ),
        DocumentFormField(
          id: 'product_name',
          label: "Tovar nomi va modeli",
          placeholder: "Masalan: 'Artel' kir yuvish mashinasi",
        ),
        DocumentFormField(
          id: 'product_price',
          label: "To'langan pul miqdori (so'mda)",
          placeholder: "Masalan: 4 500 000 so'm",
          fieldType: DocumentFieldType.number,
        ),
        DocumentFormField(
          id: 'defect_details',
          label: "Aniqlangan nuqson va kamchiliklar tavsifi",
          placeholder: "Masalan: Ishlatish jarayonida suv isitish tizimi ishlamay qoldi...",
          fieldType: DocumentFieldType.multiline,
        ),
      ],
      templateText: """
KIMGA: {{store_name}}
KIMDAN: {{applicant_name}}
MANZIL: {{applicant_address}}

TALABNOMA (PRETENZIYA)
(Sifatsiz tovar uchun to'langan pul mablag'ini qaytarish to'g'risida)

Men, {{applicant_name}}, {{purchase_date}} sanasida Sizning savdo do'koningizdan {{product_price}} evaziga {{product_name}} tovarini xarid qilgan edim.

Biroq, tovarni foydalanish jarayonida quyidagi jiddiy nuqsonlar aniqlandi:
{{defect_details}}

O'zbekiston Respublikasining "Iste'molchilarning huquqlarini himoya qilish to'g'risida"gi Qonunining 13 va 18-moddalariga muvofiq, iste'molchi nuqsonli tovar sotilganda shartnomani bekor qilish va to'langan pul summasini to'liq qaytarib olishni talab qilishga haqlidir.

Yuqoridagilardan kelib chiqib, SIZDAN:
1. {{product_name}} tovari uchun to'langan {{product_price}} miqdoridagi pul mablag'ini 10 kunlik muddatda menga to'liq qaytarishingizni;
2. Mazkur talabnoma yuzasidan qonunda belgilangan muddatda yozma javob berishingizni talab qilaman.

Aks holda, ushbu masala yuzasidan Iste'molchilar huquqlarini himoya qilish agentligiga hamda Fuqarolik ishlari bo'yicha sudga da'vo arizasi kiritilishini va barcha sud xarajatlari hamda ma'naviy zarar Sizdan undirilishini ma'lum qilaman.

Ilova: 
1. Xarid cheki / kvitansiya nusxasi.
2. Kafolat taloni nusxasi.

Sana: {{purchase_date}}
Imzo: ______________ ({{applicant_name}})
""",
    ),

    // 2. Mehnat huquqi
    const DocumentTemplate(
      id: 'template_labor_complaint',
      title: "Noqonuniy ishdan bo'shatish ustidan shikoyat",
      category: "Mehnat huquqi",
      legalBasisSummary: "Mehnat kodeksi 161, 437, 560-moddalari",
      description: "Ish beruvchining asossiz bo'shatish buyrug'i ustidan Mehnat inspeksiyasi yoki Sudga kiritiladigan rasmiy shikoyat arizasi.",
      icon: Icons.work_outline_rounded,
      color: AppColors.primary,
      fields: [
        DocumentFormField(
          id: 'authority_name',
          label: "Shikoyat yuborilayotgan organ",
          placeholder: "Masalan: Davlat mehnat inspeksiyasi boshlig'iga / Fuqarolik sudiga",
        ),
        DocumentFormField(
          id: 'applicant_name',
          label: "Ariza beruvchi xodim F.I.Sh",
          placeholder: "Masalan: Aliyev Botir Salimovich",
        ),
        DocumentFormField(
          id: 'applicant_phone',
          label: "Telefon raqami va manzili",
          placeholder: "Masalan: +998901112233, Toshkent sh.",
        ),
        DocumentFormField(
          id: 'company_name',
          label: "Ish beruvchi tashkilot nomi",
          placeholder: "Masalan: 'Grand Logistics' MCHJ",
        ),
        DocumentFormField(
          id: 'position_name',
          label: "Egallab turgan lavozimi",
          placeholder: "Masalan: Bosh hisobchi",
        ),
        DocumentFormField(
          id: 'order_number_date',
          label: "Ishdan bo'shatish buyrug'i raqami va sanasi",
          placeholder: "Masalan: 10.08.2026 yildagi 45-k sonli buyruq",
        ),
        DocumentFormField(
          id: 'violation_details',
          label: "Huquqbuzarlik tafsilotlari (qanday majburlangan/qonun buzilgan)",
          placeholder: "Masalan: Hech qanday yozma ogohlantirish berilmasdan, majburan o'z xohishi bilan ariza yozdirildi...",
          fieldType: DocumentFieldType.multiline,
        ),
      ],
      templateText: """
KIMGA: {{authority_name}}
KIMDAN: {{applicant_name}}
ALOQA: {{applicant_phone}}

SHIKOYAT ARIZASI
(Ish beruvchining noqonuniy xatti-harakatlari va asossiz ishdan bo'shatish ustidan)

Men, {{applicant_name}}, {{company_name}} tashkilotida {{position_name}} lavozimida ishlab kelganman.

Biroq, ish beruvchi tomonidan {{order_number_date}} bilan men bilan tuzilgan mehnat shartnomasi qonunga zid ravishda bekor qilindi.
Mazkur jarayonda quyidagi noqonuniy holatlarga yo'l qo'yildi:
{{violation_details}}

O'zbekiston Respublikasining Mehnat kodeksining 161, 437 va 560-moddalariga muvofiq, ish beruvchi tashabbusi bilan shartnomani bekor qilishda xodimni yozma ogohlantirish, kasaba uyushmasi roziligini olish va qat'iy qonuniy asoslar bo'lishi talab etiladi.

Yuqoridagilarga asosan, SIZDAN:
1. {{company_name}} tashkilotining {{order_number_date}} sonli buyrug'ini qonunga xilof deb topib, bekor qilishda amaliy yordam berishingizni;
2. Meni avvalgi {{position_name}} lavozimimga ishga tiklash hamda majburiy progul kunlari uchun o'rtacha oylik ish haqini ish beruvchidan undirib berishingizni so'rayman.

Ilova: Mehnat daftarchasi, buyruq nusxasi, pasport nusxasi.

Sana: ____________
Imzo: ______________ ({{applicant_name}})
""",
    ),

    // 3. Yo'l harakati
    const DocumentTemplate(
      id: 'template_traffic_fine_appeal',
      title: "Yo'l harakati jarimasi ustidan shikoyat arizasi",
      category: "Yo'l harakati",
      legalBasisSummary: "Ma'muriy javobgarlik to'g'risidagi kodeks 315-moddasi",
      description: "Radarlar yoki YPX xodimi tomonidan noo'rin yozilgan ma'muriy jarima qarorini bekor qilish bo'yicha rasmiy ariza.",
      icon: Icons.directions_car_rounded,
      color: AppColors.lexBlue,
      fields: [
        DocumentFormField(
          id: 'court_or_authority',
          label: "Shikoyat qilinayotgan organ (YHXX / Sud)",
          placeholder: "Masalan: Toshkent shahar YHXX boshlig'iga",
        ),
        DocumentFormField(
          id: 'driver_name',
          label: "Haydovchi F.I.Sh",
          placeholder: "Masalan: Yusupov Sardor Alisherovich",
        ),
        DocumentFormField(
          id: 'car_number',
          label: "Avtotransport davlat raqami va modeli",
          placeholder: "Masalan: 01 A 777 AA, Chevrolet Lacetti",
        ),
        DocumentFormField(
          id: 'fine_decision_number',
          label: "Jarima qarori raqami va sanasi",
          placeholder: "Masalan: 12.08.2026 yildagi AA-1234567 sonli qaror",
        ),
        DocumentFormField(
          id: 'appeal_reason',
          label: "Jarima nima sababdan asossiz ekanligi",
          placeholder: "Masalan: Belgilangan joyda yo'l belgisi mavjud bo'lmagan / radar ruxsat etilgan tezlikni noto'g'ri qayd etgan...",
          fieldType: DocumentFieldType.multiline,
        ),
      ],
      templateText: """
KIMGA: {{court_or_authority}}
KIMDAN: {{driver_name}}
AVTOMOBIL: {{car_number}}

SHIKOYAT
(Ma'muriy jazo qo'llash to'g'risidagi qaror ustidan)

Mening boshqaruvimdagi {{car_number}} davlat raqamli avtotransport vositasiga nisbatan {{fine_decision_number}} sonli ma'muriy jarima qo'llash to'g'risida qaror chiqarilgan.

Ushbu qarorga mutlaqo qo'shilmayman, chunki:
{{appeal_reason}}

O'zbekiston Respublikasi Ma'muriy javobgarlik to'g'risidagi kodeksining 315-moddasiga ko'ra, ma'muriy jazo qo'llash to'g'risidagi qaror ustidan 10 kun muddatda shikoyat berishga haqlidirman.

Yuqoridagilardan kelib chiqib, SIZDAN:
1. {{fine_decision_number}} sonli qarorni qayta ko'rib chiqishingizni;
2. Huquqbuzarlik alomatlari mavjud bo'lmaganligi sababli ma'muriy ishni tugatish va jarima qarorini bekor qilishingizni so'rayman.

Ilova: Qaror nusxasi, videoregistrator / foto dalillar nusxasi.

Sana: ____________
Imzo: ______________ ({{driver_name}})
""",
    ),

    // 4. Fuqarolik / Qarz
    const DocumentTemplate(
      id: 'template_debt_pretenziya',
      title: "Qarzni qaytarish to'g'risida talabnoma (Pretenziya)",
      category: "Qarz va shartnomalar",
      legalBasisSummary: "Fuqarolik kodeksi 732, 735-moddalari",
      description: "Qarzni muddatida qaytarmagan shaxsga sudgacha yuboriladigan qat'iy yozma talabnoma.",
      icon: Icons.receipt_long_rounded,
      color: AppColors.amberDark,
      fields: [
        DocumentFormField(
          id: 'debtor_name',
          label: "Qarzdor shaxs F.I.Sh",
          placeholder: "Masalan: Qodirov Otabek Shuhratovich",
        ),
        DocumentFormField(
          id: 'creditor_name',
          label: "Qarz beruvchi (Sizning) F.I.Sh",
          placeholder: "Masalan: Rahimov Jamshid Komilovich",
        ),
        DocumentFormField(
          id: 'debt_date',
          label: "Qarz berilgan sana",
          placeholder: "Masalan: 15.01.2026",
          fieldType: DocumentFieldType.date,
        ),
        DocumentFormField(
          id: 'debt_amount',
          label: "Qarz summasi (so'mda)",
          placeholder: "Masalan: 15 000 000 so'm",
          fieldType: DocumentFieldType.number,
        ),
        DocumentFormField(
          id: 'due_date',
          label: "Qaytarilishi kerak bo'lgan muddat",
          placeholder: "Masalan: 01.06.2026",
          fieldType: DocumentFieldType.date,
        ),
      ],
      templateText: """
KIMGA: {{debtor_name}}
KIMDAN: {{creditor_name}}

TALABNOMA (PRETENZIYA)
(Qarz summasini qaytarish to'g'risida)

{{debt_date}} sanasida tuzilgan qarz shartnomasi (tilxat)ga muvofiq, men Sizga {{debt_amount}} miqdorida pul mablag'ini qarzga bergan edim.

Shartnomaga ko'ra, Siz qarz mablag'ini {{due_date}} sanasiga qadar to'liq qaytarishingiz lozim edi. Biroq, bugungi kunga qadar ushbu majburiyat bajarilmadi.

O'zbekiston Respublikasi Fuqarolik kodeksining 735-moddasiga ko'ra, qarz oluvchi olingan qarz summasini shartnomada nazarda tutilgan muddatda va tartibda qaytarishi shart.

Ushbu talabnoma olingan kundan boshlab 7 (yetti) kunlik muddatda {{debt_amount}} miqdoridagi qarzni to'liq qaytarishingizni TALAB QILAMAN.

Aks holda, Fuqarolik ishlari bo'yicha tumanlararo sudiga da'vo arizasi kiritilib, qarz summasi bilan birga har bir kechiktirilgan kun uchun foizlar, davlat boji va advokat xizmati xarajatlari Sizdan majburiy tartibda undirilishini ma'lum qilaman.

Sana: ____________
Imzo: ______________ ({{creditor_name}})
""",
    ),
  ];

  @override
  Future<List<DocumentTemplate>> getTemplates({String? category}) async {
    if (category == null || category.isEmpty) {
      return _templates;
    }
    return _templates.where((t) => t.category == category).toList();
  }

  @override
  Future<DocumentTemplate> getTemplateById(String id) async {
    return _templates.firstWhere(
      (t) => t.id == id,
      orElse: () => _templates.first,
    );
  }
}

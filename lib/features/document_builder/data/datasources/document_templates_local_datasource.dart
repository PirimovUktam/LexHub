import 'package:flutter/material.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_form_field.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';

abstract class DocumentTemplatesLocalDataSource {
  Future<List<DocumentTemplate>> getTemplates({String? category, String? searchQuery});
  Future<DocumentTemplate> getTemplateById(String id);
}

class DocumentTemplatesLocalDataSourceImpl implements DocumentTemplatesLocalDataSource {
  static final List<DocumentTemplate> _templates = [
    // 1. Iste'molchi huquqlari
    DocumentTemplate(
      id: 'template_consumer_refund',
      title: "Sifatsiz tovar uchun pulni qaytarish talabnomasi",
      category: "Iste'molchi huquqlari",
      legalBasisSummary: "Iste'molchilar huquqlarini himoya qilish to'g'risidagi Qonun 13, 18-moddalari",
      description: "Nuqsonli yoki sifatsiz tovar sotib olganda sotuvchiga pulni to'liq qaytarishni talab qiluvchi rasmiy da'vo arizasi.",
      icon: Icons.shopping_bag_outlined,
      color: AppColors.emerald,
      targetAuthority: "Savdo do'koni yoki sotuvchi ma'muriyatiga",
      sourceUrl: "https://lex.uz/docs/44265#44389",
      lastVerifiedAt: DateTime(2026, 1, 15),
      status: "active",
      isPopular: true,
      fields: const [
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
    DocumentTemplate(
      id: 'template_labor_complaint',
      title: "Noqonuniy ishdan bo'shatish ustidan shikoyat",
      category: "Mehnat huquqi",
      legalBasisSummary: "Mehnat kodeksi 161, 437, 560-moddalari",
      description: "Ish beruvchining asossiz bo'shatish buyrug'i ustidan Mehnat inspeksiyasi yoki Sudga kiritiladigan rasmiy shikoyat arizasi.",
      icon: Icons.work_outline_rounded,
      color: AppColors.primary,
      targetAuthority: "Davlat mehnat inspeksiyasi boshlig'iga / Fuqarolik sudiga",
      sourceUrl: "https://lex.uz/docs/6257288#6273110",
      lastVerifiedAt: DateTime(2026, 1, 15),
      status: "active",
      isPopular: true,
      fields: const [
        DocumentFormField(
          id: 'authority_name',
          label: "Shikoyat yuborilayotgan organ",
          placeholder: "Masalan: Davlat mehnat inspeksiyasiga / Toshkent sh. Fuqarolik sudiga",
        ),
        DocumentFormField(
          id: 'applicant_name',
          label: "Ariza beruvchi xodim F.I.Sh",
          placeholder: "Masalan: Aliyev Botir Salimovich",
        ),
        DocumentFormField(
          id: 'applicant_phone',
          label: "Telefon raqami va manzili",
          placeholder: "Masalan: +998901112233, Toshkent sh., Yunusobod t.",
        ),
        DocumentFormField(
          id: 'company_name',
          label: "Ish beruvchi tashkilot nomi",
          placeholder: "Masalan: 'Grand Logistics' MCHJ",
        ),
        DocumentFormField(
          id: 'job_title',
          label: "Egallab turgan lavozimingiz",
          placeholder: "Masalan: Bosh hisobchi",
        ),
        DocumentFormField(
          id: 'dismissal_date',
          label: "Bo'shatish to'g'risida buyruq sanasi",
          placeholder: "Masalan: 01.08.2026",
          fieldType: DocumentFieldType.date,
        ),
        DocumentFormField(
          id: 'violation_reason',
          label: "Qonunbuzarlik holatlari tavsifi",
          placeholder: "Masalan: Ish beruvchi ogohlantirish bermasdan va kasaba uyushmasi roziligisiz noqonuniy bo'shatdi...",
          fieldType: DocumentFieldType.multiline,
        ),
      ],
      templateText: """
KIMGA: {{authority_name}}
KIMDAN: {{applicant_name}}
MANZIL VA TEL: {{applicant_phone}}

SHIKOYAT ARIZASI
(Noqonuniy ishdan bo'shatish buyrug'ini bekor qilish va ishga tiklash to'g'risida)

Men, {{applicant_name}}, {{company_name}} tashkilotida {{job_title}} lavozimida ishlab kelganman.

Biroq, {{dismissal_date}} sanasida ish beruvchi tomonidan mehnat qonunchiligi talablariga zid ravishda mehnat shartnomasi bekor qilindi.
Qonunbuzarlik tafsilotlari:
{{violation_reason}}

O'zbekiston Respublikasining Mehnat kodeksining 161, 437 va 560-moddalariga muvofiq, ish beruvchi tashabbusi bilan shartnomani bekor qilishda qonuniy asoslar va kafolatlar ta'minlanishi shart. Noqonuniy bo'shatilgan xodim avvalgi ishiga tiklanishi hamda majburiy progul vaqti uchun o'rtacha oylik ish haqi undirilishi lozim.

Yuqoridagilarga asosan, SIZDAN:
1. Mazkur qonunbuzarlik holatini joyiga chiqqan holda o'rganib chiqishingizni;
2. {{company_name}} ma'muriyatining {{dismissal_date}} dagi noqonuniy buyrug'ini bekor qilish va meni {{job_title}} lavozimiga qayta tiklash to'g'risida ko'rsatma berishingizni (sudga da'vo kiritishingizni) so'rayman.

Ilova: 
1. Pasport nusxasi.
2. Mehnat shartnomasi va buyruq nusxasi.

Sana: {{dismissal_date}}
Imzo: ______________ ({{applicant_name}})
""",
    ),

    // 3. Oila huquqi
    DocumentTemplate(
      id: 'template_alimony_petition',
      title: "Aliment undirish to'g'risida sud buyrug'i arizasi",
      category: "Oila huquqi",
      legalBasisSummary: "Oila kodeksi 96, 99, 136-moddalari",
      description: "Voyaga yetmagan farzandlar ta'minoti uchun ota/onadan qonunda belgilangan miqdorda aliment undirish to'g'risida fuqarolik sudiga ariza.",
      icon: Icons.family_restroom_rounded,
      color: AppColors.indigo,
      targetAuthority: "Fuqarolik ishlari bo'yicha tumanlararo sudiga",
      sourceUrl: "https://lex.uz/docs/104720#107382",
      lastVerifiedAt: DateTime(2026, 1, 15),
      status: "active",
      isPopular: true,
      fields: const [
        DocumentFormField(
          id: 'court_name',
          label: "Sud nomi",
          placeholder: "Masalan: Fuqarolik ishlari bo'yicha Mirzo Ulug'bek tumanlararo sudiga",
        ),
        DocumentFormField(
          id: 'applicant_name',
          label: "Undiruvchi (Ariza beruvchi) F.I.Sh",
          placeholder: "Masalan: Karimova Dilnoza Anvarovna",
        ),
        DocumentFormField(
          id: 'applicant_address',
          label: "Undiruvchi manzili va tel",
          placeholder: "Masalan: Toshkent sh., Buyuk Ipak Yo'li 45, +998901234567",
        ),
        DocumentFormField(
          id: 'debtor_name',
          label: "Qarzdor (Javobgar) F.I.Sh",
          placeholder: "Masalan: Karimov Rustam Botirovich",
        ),
        DocumentFormField(
          id: 'debtor_address',
          label: "Qarzdorning yashash yoki ish joyi",
          placeholder: "Masalan: Toshkent sh., Chilonzor 5-mavze 12-uy",
        ),
        DocumentFormField(
          id: 'children_info',
          label: "Voyaga yetmagan bolalar F.I.Sh va tug'ilgan sanalari",
          placeholder: "Masalan: Karimov Jasur (2018-yil) va Karimova Madina (2021-yil)",
          fieldType: DocumentFieldType.multiline,
        ),
      ],
      templateText: """
KIMGA: {{court_name}}
UNDIRUVCHI: {{applicant_name}}
MANZIL: {{applicant_address}}
QARZDOR: {{debtor_name}}
QARZDOR MANZILI: {{debtor_address}}

SUD BUYRUG'I CHIQARISH TO'G'RISIDA ARIZA
(Voyaga yetmagan bolalar ta'minoti uchun aliment undirish haqida)

Men va javobgar {{debtor_name}} qonuniy nikohdan o'tganmiz (yoki birgalikda yashab kelganmiz). O'rtamizdagi nikohdan quyidagi voyaga yetmagan farzandlarimiz bor:
{{children_info}}

Hozirgi kunda bolalar to'liq mening qaramog'imda bo'lib, qarzdor {{debtor_name}} farzandlarining moddiy ta'minotida ishtirok etmayapti va ixtiyoriy ravishda yordam berishdan bosh tortmoqda.

O'zbekiston Respublikasi Oila kodeksining 96-moddasiga binoan, ota-ona voyaga yetmagan bolalariga ta'minot berishi shart. Kodeksning 99-moddasiga ko'ra, voyaga yetmagan bolalar uchun aliment ota-onaning har oylik ish haqi va boshqa daromadining tegishli qismi miqdorida undiriladi.

Yuqoridagilarga asosan, O'zbekiston Respublikasi Fuqarolik protsessual kodeksining 170-172-moddalariga muvofiq, SIZDAN:
Qarzdor {{debtor_name}}dan mening foydamga voyaga yetmagan farzandlarimiz ta'minoti uchun har oylik daromadining qonunda belgilangan qismi miqdorida bolalar voyaga yetguniga qadar aliment undirish to'g'risida SUD BUYRUG'I chiqarishingizni so'rayman.

Ilova:
1. Nikoh to'g'risidagi guvohnoma (yoki ajrim) nusxasi.
2. Bolalarning tug'ilganlik to''g'risidagi guvohnomalari nusxalari.
3. Mahalla yoki yashash joyidan bolalar mening qaramog'imdaligi haqida ma'lumotnoma.

Sana: {{applicant_address}}
Imzo: ______________ ({{applicant_name}})
""",
    ),

    // 4. Yo'l harakati
    DocumentTemplate(
      id: 'template_traffic_fine_appeal',
      title: "YHQ jarima qarori ustidan shikoyat arizasi",
      category: "Yo'l harakati",
      legalBasisSummary: "MJtK 315, 316, 332-1-moddalari",
      description: "Asossiz yoki xato yozilgan yo'l harakati qoidabuzarligi jarimasi ustidan YHXX yoki Sudga beriladigan shikoyat.",
      icon: Icons.directions_car_outlined,
      color: AppColors.amber,
      targetAuthority: "Toshkent shahar IIBB YHXX boshlig'iga / Sudga",
      sourceUrl: "https://lex.uz/docs/97661#1184234",
      lastVerifiedAt: DateTime(2026, 1, 15),
      status: "active",
      isPopular: false,
      fields: const [
        DocumentFormField(
          id: 'authority_name',
          label: "Shikoyat berilayotgan YHXX bo'limi",
          placeholder: "Masalan: Toshkent shahar IIBB YHXX boshlig'iga",
        ),
        DocumentFormField(
          id: 'driver_name',
          label: "Haydovchi (Ariza beruvchi) F.I.Sh",
          placeholder: "Masalan: Rustamov Jasur Anvarovich",
        ),
        DocumentFormField(
          id: 'driver_phone',
          label: "Telefon raqami va manzili",
          placeholder: "Masalan: +998901234567, Toshkent sh.",
        ),
        DocumentFormField(
          id: 'fine_number',
          label: "Jarima qarori raqami va sanasi",
          placeholder: "Masalan: AB 12345678, 10.08.2026",
        ),
        DocumentFormField(
          id: 'car_number',
          label: "Avtotransport davlat raqami",
          placeholder: "Masalan: 01 A 777 AA",
        ),
        DocumentFormField(
          id: 'appeal_reason',
          label: "Jarima noto'g'ri qo'llanilgani sababi",
          placeholder: "Masalan: Radar ko'rsatgan vaqtda transport vositasini boshqa shaxs ishonchnoma bilan boshqarayotgan edi / Yo'l belgisi ko'rinmas holatda edi...",
          fieldType: DocumentFieldType.multiline,
        ),
      ],
      templateText: """
KIMGA: {{authority_name}}
KIMDAN: {{driver_name}}
MANZIL VA TEL: {{driver_phone}}

SHIKOYAT ARIZASI
(Ma'muriy jarima qarorini bekor qilish to'g'risida)

Men, {{driver_name}}, o'zimga tegishli {{car_number}} davlat raqamli avtomashina yuzasidan chiqarilgan {{fine_number}} sonli ma'muriy jarima qaroriga e'tiroz bildiraman.

Mazkur qaror quyidagi sabablarga ko'ra asossiz va noto'g'ri deb hisoblayman:
{{appeal_reason}}

O'zbekiston Respublikasining Ma'muriy javobgarlik to'g'risidagi kodeksining 315 va 316-moddalariga muvofiq, ma'muriy jazo qo'llash to'g'risidagi qaror ustidan yuqori turuvchi organga yoki sudga 10 kunlik muddatda shikoyat berishga haqlidirman.

Yuqoridagilardan kelib chiqib, SIZDAN:
1. {{fine_number}} sonli ma'muriy huquqbuzarlik to'g'risidagi qarorni qayta ko'rib chiqishingizni;
2. Mazkur qarorni asossiz deb topib, ma'muriy ishni harakatdan tugatishingizni so'rayman.

Ilova:
1. Haydovchilik guvohnomasi va texnik pasport nusxasi.
2. Jarima qarori nusxasi.
3. Daliliy fotosuratlar / videoyozuvlar.

Sana: {{fine_number}}
Imzo: ______________ ({{driver_name}})
""",
    ),
  ];

  @override
  Future<List<DocumentTemplate>> getTemplates({String? category, String? searchQuery}) async {
    List<DocumentTemplate> result = List.from(_templates);

    if (category != null && category != 'Barchasi') {
      result = result.where((t) => t.category.toLowerCase().contains(category.toLowerCase())).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      result = result.where((t) =>
          t.title.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q) ||
          t.legalBasisSummary.toLowerCase().contains(q)).toList();
    }

    return result;
  }

  @override
  Future<DocumentTemplate> getTemplateById(String id) async {
    final template = _templates.firstWhere(
      (t) => t.id == id,
      orElse: () => _templates.first,
    );
    return template;
  }
}

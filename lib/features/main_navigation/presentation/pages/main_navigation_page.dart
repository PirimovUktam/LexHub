import 'package:flutter/material.dart';
import 'package:lexhub/features/citizen_services/presentation/pages/citizen_services_page.dart';
import 'package:lexhub/features/community_forum/presentation/pages/community_forum_page.dart';
import 'package:lexhub/features/home/presentation/pages/home_page.dart';
import 'package:lexhub/features/legal_assistant/presentation/pages/legal_assistant_page.dart';
import 'package:lexhub/features/main_navigation/presentation/widgets/lex_bottom_nav.dart';
import 'package:lexhub/features/saved_cases/presentation/pages/documents_and_saved_hub_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  /// Hamjamiyatdan "AI'dan so'rash" bosilganda UZATILADIGAN savol matni.
  ///
  /// NIMA UCHUN STATE'DA: `IndexedStack` (pastda) `LegalAssistantPage` ni
  /// TIRIK saqlaydi, ya'ni uning `initState` faqat BIR marta ishlaydi.
  /// Savolni konstruktorga berishning o'zi kifoya QILMAYDI — sahifa
  /// qayta yaratilishi kerak. Shuning uchun `_aiPageRevision` kalitni
  /// o'zgartiradi va faqat SAVOL YUBORILGANDA remount bo'ladi; oddiy tab
  /// almashinuvida revision o'zgarmaydi, ya'ni yozilgan matn va olingan
  /// javob YO'QOLMAYDI.
  String? _pendingAiQuery;
  int _aiPageRevision = 0;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// TUZATILGAN NUQSON (audit): ilgari bu callback `query` ni QABUL QILIB,
  /// hech qayerga uzatmasdan TASHLAB YUBORARDI:
  ///
  ///     onSendQueryToAI: (query) { _navigateToTab(1); }
  ///
  /// Natijada foydalanuvchi hamjamiyat savolida "AI'dan so'rash" ni bossa,
  /// BO'SH "Maslahat" ekraniga tushardi — savolini qaytadan yozishi kerak
  /// edi. `LegalAssistantPage` esa `initialQuery` ni ALLAQACHON qo'llab
  /// quvvatlaydi (`legal_assistant_page.dart:33,76`) va bu parametr boshqa
  /// ikki joyda TO'G'RI ishlatiladi (`home_page.dart:535`,
  /// `faq_questions_page.dart:205`) — ya'ni quvurning faqat SHU bo'g'ini
  /// uzilgan edi (§20: jim ma'lumot yo'qotish).
  ///
  /// IKKINCHI NUQSON: `CommunityForumPage` ikki xil yo'l bilan ochiladi —
  /// tab sifatida (indeks 2) VA `Navigator.push` orqali ustiga route
  /// sifatida (`quick_access_grid.dart:84`, `home_page.dart:314`). Push
  /// qilingan holatda `_navigateToTab(1)` tab'ni PARDA OSTIDA almashtirardi:
  /// ekranda hech narsa o'zgarmasdi, tugma O'LIK ko'rinardi. Shuning uchun
  /// avval o'z route'imizgacha `popUntil` qilinadi.
  void _sendQueryToAI(BuildContext context, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      // Bo'sh matn uchun sahifani remount qilishning ma'nosi yo'q —
      // shunchaki bo'limga o'tiladi.
      _navigateToTab(1);
      return;
    }

    final navigator = Navigator.of(context);
    final ownRoute = ModalRoute.of(context);
    if (ownRoute != null && navigator.canPop()) {
      // `(r) => r.isFirst` ATAYLAB ishlatilmaydi: `MainNavigationPage`
      // ba'zi yo'llarda birinchi route BO'LMAYDI
      // (`register_page.dart:403`, `login_page.dart:298` uni push qiladi),
      // va u holda `isFirst` bizning sahifamizni ham yopib tashlaydi.
      navigator.popUntil((route) => route == ownRoute);
    }

    setState(() {
      _pendingAiQuery = trimmed;
      _aiPageRevision++;
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    // TARTIB QULFLANGAN: 0 Bosh sahifa, 1 Maslahat, 2 Hamjamiyat,
    // 3 Xizmatlar, 4 Kabinet. `onAskAITap: () => _navigateToTab(1)` va
    // shunga o'xshash mavjud chaqiruvlar shu tartibga bog'langan —
    // `LexBottomNav` faqat KO'RSATISH tartibini o'zgartiradi.
    final pages = [
      HomePage(
        onAskAITap: () => _navigateToTab(1),
        onSendQueryToAI: (query) => _sendQueryToAI(context, query),
      ),
      LegalAssistantPage(
        // Kalit REVISION bilan o'zgaradi — faqat yangi savol kelganda
        // sahifa qayta quriladi (yuqoridagi izohga qara).
        key: ValueKey<int>(_aiPageRevision),
        initialQuery: _pendingAiQuery,
      ),
      CommunityForumPage(
        onSendQueryToAI: (query) => _sendQueryToAI(context, query),
      ),
      const CitizenServicesPage(),
      const DocumentsAndSavedHubPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: LexBottomNav(
        currentIndex: _currentIndex,
        onSelect: _navigateToTab,
      ),
    );
  }
}

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

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
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
        onSendQueryToAI: (query) {
          _navigateToTab(1);
        },
      ),
      const LegalAssistantPage(),
      CommunityForumPage(
        onSendQueryToAI: (query) {
          _navigateToTab(1);
        },
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

import 'package:flutter/material.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/features/citizen_services/presentation/pages/citizen_services_page.dart';
import 'package:lexhub/features/community_forum/presentation/pages/community_forum_page.dart';
import 'package:lexhub/features/home/presentation/pages/home_page.dart';
import 'package:lexhub/features/legal_assistant/presentation/pages/legal_assistant_page.dart';
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _navigateToTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: Icon(
              Icons.home_rounded,
              color: isDark ? AppColors.indigo : AppColors.primary,
            ),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon:
                const Icon(Icons.auto_awesome_rounded, color: AppColors.indigo),
            label: l10n.navAI,
          ),
          NavigationDestination(
            icon: const Icon(Icons.forum_outlined),
            selectedIcon: Icon(
              Icons.forum_rounded,
              color: isDark ? AppColors.indigo : AppColors.primary,
            ),
            label: l10n.navCommunity,
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(
              Icons.account_balance_rounded,
              color: isDark ? AppColors.emerald : AppColors.emeraldDark,
            ),
            label: l10n.navServices,
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_open_rounded),
            selectedIcon: Icon(
              Icons.folder_rounded,
              color: isDark ? AppColors.accent : AppColors.accentDark,
            ),
            label: l10n.navCabinet,
          ),
        ],
      ),
    );
  }
}

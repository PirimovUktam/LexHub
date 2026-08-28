import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/home/data/datasources/home_local_datasource.dart';
import 'package:lexhub/features/home/domain/entities/legal_category.dart';
import 'package:lexhub/features/home/domain/entities/seed_question.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/presentation/pages/legal_assistant_page.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/action_steps_timeline.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/legal_basis_accordion.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/relatable_summary_card.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/risk_matrix_gauge.dart';

class FaqQuestionsPage extends StatefulWidget {
  final String? initialCategoryId;

  const FaqQuestionsPage({super.key, this.initialCategoryId});

  @override
  State<FaqQuestionsPage> createState() => _FaqQuestionsPageState();
}

class _FaqQuestionsPageState extends State<FaqQuestionsPage> {
  late final TextEditingController _searchController;
  final HomeLocalDataSource _dataSource = sl<HomeLocalDataSource>();

  List<LegalCategory> _categories = [];
  List<SeedQuestionModel> _allQuestions = [];
  List<SeedQuestionModel> _filteredQuestions = [];

  String? _selectedCategoryId;
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedCategoryId = widget.initialCategoryId;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final categories = await _dataSource.getCategories();
    final questions = await _dataSource.getSeedQuestions();

    setState(() {
      _categories = categories;
      _allQuestions = questions;
      _isLoading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<SeedQuestionModel> list = List.from(_allQuestions);

    if (_selectedCategoryId != null) {
      list = list.where((q) => q.categoryId == _selectedCategoryId).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((item) {
        return item.questionText.toLowerCase().contains(q) ||
            item.relatableSummary.toLowerCase().contains(q) ||
            item.categoryName.toLowerCase().contains(q);
      }).toList();
    }

    setState(() {
      _filteredQuestions = list;
    });
  }

  void _onCategorySelected(String? catId) {
    setState(() {
      _selectedCategoryId = catId;
    });
    _applyFilters();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  void _showDetailModal(BuildContext context, SeedQuestionModel item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const Gap(12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Gap(12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(18),
                  children: [
                    // §6: KO'RISHLAR SONI OLIB TASHLANDI. Seed savollar statik
                    // `home_local_datasource` ro'yxatidan keladi va ilovada
                    // ko'rishni hisoblaydigan hech qanday mexanizm yo'q edi —
                    // ekranda ko'rsatilgan "1420 marta ko'rildi" TO'QIMA raqam
                    // bo'lgan. Haqiqiy hisoblagich paydo bo'lgunicha raqamni
                    // ko'rsatmaslik to'g'ri: yolg'on metrikadan yaxshi.
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.indigoDarkBg : AppColors.indigoLight,
                            borderRadius: BorderRadius.circular(8),
                            border: isDark ? Border.all(color: AppColors.indigoDarkBorder) : null,
                          ),
                          // O'LCHANGAN DEFEKT: qorong'ida XOM `indigo`
                          // `indigoDarkBg` ustida 3.58:1 — 12 px qalin matn
                          // uchun AA (4.5:1) dan past. Yorug' tomon
                          // (`indigoDark`, 5.62:1) O'ZGARMAYDI, chunki ton
                          // uning yorug' jufti aynan `indigoDark`. Ton
                          // qorong'ida: 8.02:1.
                          child: Text(
                            homeCategoryLabel(l10n, item.categoryName),
                            style: TextStyle(
                              color: AppTone.accentIndigo.on(isDark),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(14),
                    Text(
                      item.questionText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const Gap(16),
                    // HALOLLIK: bu ekrandagi javoblar `SeedQuestionModel` —
                    // ilova ichiga oldindan yozib qo'yilgan seed kontent
                    // (`seed_question.dart` da `source` maydoni YO'Q, chunki
                    // bu yerda hech qachon model chaqirilmaydi). Shuning uchun
                    // manba QAT'IY `sourceDeterministic`; bu qiymat state'dan
                    // kelmasligi ATAYLAB.
                    RelatableSummaryCard(
                      summary: item.relatableSummary,
                      source: LegalResponse.sourceDeterministic,
                    ),
                    const Gap(14),
                    ActionStepsTimeline(steps: item.actionableSteps),
                    const Gap(14),
                    LegalBasisAccordion(articles: item.legalBasis),
                    const Gap(14),
                    RiskMatrixGauge(assessment: item.riskAssessment),
                    const Gap(20),

                    // Direct Consult Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LegalAssistantPage(
                              initialQuery: item.questionText,
                              initialCategory: item.categoryName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(l10n.faqAskAiAction),
                    ),
                    const Gap(24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.faqBannerTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: l10n.faqSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      fillColor: isDark ? AppColors.cardDark : theme.colorScheme.surface,
                    ),
                  ),
                ),

                // Category Chips Selector
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          // `RawChip` yorliqni o'lchangan kenglikka TENG
                          // `maxWidth` bilan qayta layout qiladi va
                          // `TextOverflow.fade` ni majburlaydi — oxirgi glif
                          // so'nadi (qurilmada tasdiqlangan).
                          label: Text(l10n.categoryAll,
                              overflow: TextOverflow.visible),
                          selected: _selectedCategoryId == null,
                          onSelected: (_) => _onCategorySelected(null),
                        ),
                      ),
                      ..._categories.map((cat) {
                        final isSelected = _selectedCategoryId == cat.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(homeCategoryLabel(l10n, cat.title),
                                overflow: TextOverflow.visible),
                            selected: isSelected,
                            onSelected: (_) => _onCategorySelected(isSelected ? null : cat.id),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const Gap(12),

                // Header info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.faqLegalCasesCount(_filteredQuestions.length),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      // O'LCHANGAN DEFEKT: yorug'da `emeraldDark` sahifa foni
                      // ustida 3.60:1 — 11 px qalin matn uchun AA'dan past.
                      // Ton: 7.34 / 9.16.
                      Text(
                        l10n.faqWithLexUz,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTone.success.on(isDark),
                        ),
                      ),
                    ],
                  ),
                ),

                const Gap(6),

                // Questions List
                Expanded(
                  child: _filteredQuestions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 48,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                                const Gap(12),
                                Text(
                                  l10n.faqNoMatches,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const Gap(6),
                                Text(
                                  l10n.faqNoMatchesHint,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredQuestions.length,
                          separatorBuilder: (_, __) => const Gap(12),
                          itemBuilder: (context, index) {
                            final item = _filteredQuestions[index];

                            return ModernContainer(
                              onTap: () => _showDetailModal(context, item),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppColors.indigo.withValues(alpha: 0.18)
                                              : AppColors.primary.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        // O'LCHANGAN DEFEKT: qorong'ida yorliq
                                        // XOM `indigo`, foni AYNI rangning 18%
                                        // tinti -> 2.69:1. Ton: 6.04:1. Yorug'
                                        // tomonda `primary` (15.17:1) ATAYLAB
                                        // qoldirildi — u neytral navy, indigo
                                        // emas.
                                        child: Text(
                                          homeCategoryLabel(l10n, item.categoryName),
                                          style: TextStyle(
                                            color: isDark
                                                ? AppTone.accentIndigo.on(true)
                                                : AppColors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (item.legalBasis.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppColors.lexBlueDarkBg : AppColors.lexBlueLight,
                                            borderRadius: BorderRadius.circular(6),
                                            border: isDark ? Border.all(color: AppColors.lexBlueDarkBorder) : null,
                                          ),
                                          // O'LCHANGAN DEFEKT: qorong'ida
                                          // `lexBlue` `lexBlueDarkBg` ustida
                                          // 3.85:1 — AA'dan past. Ton:
                                          // 6.59 / 7.35 (fon O'ZGARMAYDI).
                                          child: Text(
                                            item.legalBasis.first.articleNumber,
                                            style: TextStyle(
                                              color: AppTone.info.on(isDark),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Gap(10),
                                  Text(
                                    item.questionText,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                  ),
                                  const Gap(8),
                                  Text(
                                    item.relatableSummary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      height: 1.45,
                                    ),
                                  ),
                                  const Gap(12),
                                  Row(
                                    children: [
                                      // §6: to'qima "ko'rishlar soni" olib
                                      // tashlandi (yuqoridagi izohga qara).
                                      const Spacer(),
                                      // O'LCHANGAN DEFEKT: qorong'ida `indigo`
                                      // `cardDark` ustida 3.27:1 — 12 px qalin
                                      // matn uchun AA'dan past. Ton: 7.34:1.
                                      Text(
                                        l10n.actionReadAnalysis,
                                        style: TextStyle(
                                          color: isDark
                                              ? AppTone.accentIndigo.on(true)
                                              : AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Gap(4),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 14,
                                        color: isDark
                                            ? AppTone.accentIndigo.on(true)
                                            : AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

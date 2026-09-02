import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/auth/presentation/pages/login_page.dart';
import 'package:lexhub/features/community_forum/data/datasources/question_category_resolver.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AskCommunityDialog extends StatefulWidget {
  final String? initialText;
  final String? initialCategory;
  final ValueChanged<CommunityPost>? onPostSubmitted;
  final ValueChanged<String>? onPublished;

  const AskCommunityDialog({
    super.key,
    this.initialText,
    this.initialCategory,
    this.onPostSubmitted,
    this.onPublished,
  });

  static void showAuthRequiredDialog(BuildContext context, {required String actionText}) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Row(
          children: [
            // O'LCHANGAN: qulf ikonkasi `AppColors.primary` (#0F172A) edi va
            // qorong'i mavzuda dialog foni AYNI `surfaceDark` (#0F172A) —
            // 1.00:1, ya'ni ikonka KO'RINMASDI. Endi ton bo'yicha (8.96:1).
            Icon(Icons.lock_outline_rounded,
                color: AppTone.accentIndigo.on(isDark)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.authRequiredTitle,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.authRequiredMessage(actionText),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              // Xuddi shu sabab: `primary` fon qorong'i dialog yuzasi bilan
              // 1.00:1 edi — tugma yuzasi umuman ajralmasdi. Qorong'ida
              // yorqin `indigoOnTintDark` fon + to'q `primary` yorliq
              // ishlatiladi: yorliq 8.96:1, yuza chegarasi ham 8.96:1
              // (`indigoDark` fon 2.84:1 chegara berardi — 1.4.11 dan past,
              // `indigo` esa oq yorliq bilan 4.47:1, matn uchun past).
              backgroundColor:
                  isDark ? AppColors.indigoOnTintDark : AppColors.primary,
              foregroundColor: isDark ? AppColors.primary : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: Text(l10n.authLoginOrRegister),
          ),
        ],
      ),
    );
  }

  static void show(
    BuildContext context, {
    String? initialText,
    String? initialCategory,
    ValueChanged<CommunityPost>? onPostSubmitted,
    ValueChanged<String>? onPublished,
  }) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      showAuthRequiredDialog(context,
          actionText: context.l10n.authActionAskQuestion);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: AskCommunityDialog(
          initialText: initialText,
          initialCategory: initialCategory,
          onPostSubmitted: onPostSubmitted,
          onPublished: onPublished,
        ),
      ),
    );
  }

  @override
  State<AskCommunityDialog> createState() => _AskCommunityDialogState();
}

class _AskCommunityDialogState extends State<AskCommunityDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _textController;
  late String _selectedCategory;
  String _anonymizedPreview = '';
  bool _isAnonymous = true;

  /// Faqat `public.categories`da REAL mavjud nomlar. Katalogda yo'q nomni
  /// ko'rsatish savolni saqlanmaydigan tanlovga olib boradi (22P02 / 422).
  static const List<String> _categories = kCommunityCategoryNames;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _textController = TextEditingController(text: widget.initialText ?? '');
    _selectedCategory = _matchKnownCategory(widget.initialCategory);
    _updateAnonymizedPreview(_textController.text);
  }

  /// Tashqaridan kelgan nom (masalan FAQ `categoryName`) dropdown ro'yxatida
  /// bo'lmasa, birinchi real kategoriyaga qaytadi — aks holda Dropdown
  /// "exactly one item" assertion bilan yiqiladi va katalogda yo'q nom
  /// keyinroq `category_id`ga yetib borishga urinadi.
  static String _matchKnownCategory(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return _categories.first;
    final normalized = QuestionCategoryCatalog.normalizeName(value);
    for (final known in _categories) {
      if (QuestionCategoryCatalog.normalizeName(known) == normalized) {
        return known;
      }
    }
    return _categories.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _updateAnonymizedPreview(String text) {
    setState(() {
      _anonymizedPreview = PiiAnonymizer.anonymize(text);
    });
  }

  void _publish() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      Navigator.pop(context);
      AskCommunityDialog.showAuthRequiredDialog(context,
          actionText: context.l10n.authActionAskQuestion);
      return;
    }

    final title = _titleController.text.trim();
    final text = _textController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.askDialogEmptyBody)),
      );
      return;
    }

    final postTitle = title.isNotEmpty ? title : (text.length > 50 ? "${text.substring(0, 50)}..." : text);
    final sanitized = PiiAnonymizer.anonymize(text);

    final newPost = CommunityPost(
      id: "post_${DateTime.now().millisecondsSinceEpoch}",
      title: postTitle,
      anonymizedQuestion: sanitized,
      category: _selectedCategory,
      aiSummary: CommunityPost.categoryRoutingNote(_selectedCategory),
      helpfulCount: 1,
      viewsCount: 1,
      answersCount: 0,
      isAnonymous: _isAnonymous,
      authorName: _isAnonymous ? "Anonim fuqaro" : "Fuqaro",
      createdAt: DateTime.now(),
      isLikedByMe: true,
      answers: const [],
    );

    Navigator.pop(context);

    if (widget.onPostSubmitted != null) {
      widget.onPostSubmitted!(newPost);
    } else if (widget.onPublished != null) {
      widget.onPublished!(sanitized);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final containsPii = PiiAnonymizer.containsPii(_textController.text);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Gap(AppSpacing.md + 2),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    // O'LCHANGAN: tint fon + AYNI tondan ikonka. Ilgari
                    // qorong'ida ikonka o'z tinti (`indigo@0.2`) ustida
                    // 3.16:1 edi — 1.4.11 ning grafik minimumidan (3:1)
                    // ARANG yuqori, ya'ni zaxira yo'q. Endi eng yomon holatda
                    // 5.91:1 (yorug'da 4.67:1; eski yorug' qiymat 14.56:1
                    // AA'dan o'tardi, o'zgarish faqat ton birligi uchun).
                    color: AppTone.accentIndigo.bg(isDark),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border:
                        Border.all(color: AppTone.accentIndigo.border(isDark)),
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    color: AppTone.accentIndigo.on(isDark),
                    size: AppIconSize.md,
                  ),
                ),
                const Gap(AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.askDialogTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l10n.askDialogPrivacyGuard,
                        style: theme.textTheme.bodySmall?.copyWith(
                          // O'LCHANGAN: yorug' mavzuda `emeraldDark` dialog
                          // yuzasi (#F8FAFC) ustida 3.60:1 edi — 11 px matn
                          // uchun AA (4.5:1) dan past. `AppTone.success.on`
                          // yorug'da `emeraldStrong` (7.34:1), qorong'ida
                          // `emeraldOnDark` (9.16:1) beradi.
                          color: AppTone.success.on(isDark),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Gap(AppSpacing.lg),

            // Category Selector
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration:
                  InputDecoration(labelText: l10n.askDialogCategoryField),
              dropdownColor: theme.colorScheme.surface,
              items: _categories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat,
                  child: Text(categoryLabel(l10n, cat)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategory = val;
                  });
                }
              },
            ),

            const Gap(AppSpacing.md + 2),

            // Question Title Input
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.askDialogTitleField,
                hintText: l10n.askDialogTitleHint,
              ),
            ),

            const Gap(AppSpacing.md + 2),

            // Question Details Input
            TextField(
              controller: _textController,
              maxLines: 4,
              onChanged: _updateAnonymizedPreview,
              decoration: InputDecoration(
                labelText: l10n.askDialogBodyField,
                hintText: l10n.askDialogBodyHint,
              ),
            ),

            // Anonymous Toggle Switch
            const Gap(AppSpacing.sm + 2),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.askDialogAnonymousToggle,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(l10n.askDialogAnonymousSubtitle,
                  style: const TextStyle(fontSize: 11)),
              value: _isAnonymous,
              onChanged: (val) {
                setState(() {
                  _isAnonymous = val;
                });
              },
            ),

            // Real-time Privacy Sanitizer Indicator
            if (containsPii) ...[
              const Gap(AppSpacing.sm + 2),
              ModernContainer(
                padding: const EdgeInsets.all(AppSpacing.md),
                // O'LCHANGAN: yorug'da `amberDark` (#D97706) o'zining
                // `amberLight` tinti ustida 2.86:1 — matn uchun AA dan
                // ANCHA past (qorong'i juftlik 7.42:1 bilan o'tardi). Endi
                // fon/chegara/matn AYNI `AppTone.warning` dan olinadi:
                // qulflangan alfa konvertida eng yomon 5.86:1 (yorug') va
                // 7.07:1 (qorong'i).
                backgroundColor: AppTone.warning.bg(isDark),
                borderColor: AppTone.warning.border(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: AppIconSize.xs + 2,
                          color: AppTone.warning.on(isDark),
                        ),
                        const Gap(AppSpacing.xs + 2),
                        Expanded(
                          child: Text(
                            l10n.askDialogPiiDetected,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppTone.warning.on(isDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(AppSpacing.xxs),
                    Text(
                      _anonymizedPreview,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],

            const Gap(AppSpacing.lg),

            // Publish Button
            ElevatedButton.icon(
              onPressed: _publish,
              icon: const Icon(Icons.send_rounded, size: AppIconSize.sm),
              label: Text(_isAnonymous
                  ? l10n.askDialogPublishAnonymously
                  : l10n.askDialogPublish),
            ),

            const Gap(AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

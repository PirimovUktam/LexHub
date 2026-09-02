import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/role_labels.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';
import 'package:lexhub/core/network/supabase_db.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/status_badge.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/community_forum/data/datasources/answer_schema.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/domain/entities/question_answer.dart';
import 'package:lexhub/features/community_forum/domain/usecases/accept_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/add_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/vote_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/presentation/widgets/ask_community_dialog.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class QuestionDetailPage extends StatefulWidget {
  final CommunityPost post;
  final Function(String answerText, bool isExpert)? onAddAnswer;

  const QuestionDetailPage({
    super.key,
    required this.post,
    this.onAddAnswer,
  });

  @override
  State<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<QuestionDetailPage> {
  late final TextEditingController _answerController;
  late List<QuestionAnswer> _answers;
  bool _isExpertReply = false;
  bool _isSubmitting = false;

  /// REAL `public.profiles` qatoridan olingan ekspert huquqi.
  ///
  /// P0 EDI: "Advokat sifatida javob berish" chip'i HAR KIMGA, shu jumladan
  /// `role = 'citizen'` foydalanuvchiga ham ko'rinardi va u o'zini advokat
  /// deb belgilab javob yuborishi mumkin edi. DB triggeri
  /// (`enforce_expert_answer`) qiymatni JIMGINA `FALSE` qilardi — natijada
  /// UI "muvaffaqiyatli" deb yozardi, javob esa oddiy javob bo'lardi.
  /// Endi chip faqat haqli foydalanuvchiga ko'rsatiladi; qoida
  /// [canAnswerAsExpert] da — data qatlami bilan AYNAN bir xil predikat.
  bool _canAnswerAsExpert = false;

  @override
  void initState() {
    super.initState();
    _answerController = TextEditingController();
    _answers = List.from(widget.post.answers);
    _loadExpertEligibility();
  }

  /// Ekspert huquqini REAL profil qatoridan o'qiydi (fail-closed).
  Future<void> _loadExpertEligibility() async {
    try {
      // `Supabase.instance` initialize qilinmagan bo'lsa assertion tashlaydi —
      // u ham shu yerda ushlanadi (aks holda `initState`dan unhandled async
      // error chiqadi va sahifa "ekspert" holatida qolmasligi kafolatlanmaydi).
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final row = await Supabase.instance.client
          .db('profiles')
          .select('role, is_verified')
          .eq('id', userId)
          .maybeSingle();
      if (!mounted || row == null) return;
      final eligible = canAnswerAsExpert(
        role: row['role'] as String?,
        isVerified: row['is_verified'] as bool? ?? false,
      );
      if (eligible == _canAnswerAsExpert) return;
      setState(() {
        _canAnswerAsExpert = eligible;
        if (!eligible) _isExpertReply = false;
      });
    } catch (_) {
      // O'qib bo'lmadi -> eng kam imtiyoz saqlanadi (chip ko'rinmaydi).
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      AskCommunityDialog.showAuthRequiredDialog(context,
          actionText: context.l10n.authActionWriteAnswer);
      return;
    }

    final text = _answerController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    final sanitized = PiiAnonymizer.anonymize(text);

    // Ikkinchi qatlam himoya: chip yashirin bo'lsa ham `true` ketmaydi.
    // Uchinchi (asosiy) qatlam — DB triggeri `enforce_expert_answer`.
    final asExpert = _isExpertReply && _canAnswerAsExpert;

    final addAnswerUseCase = sl<AddCommunityAnswerUseCase>();
    final result = await addAnswerUseCase(
      AddCommunityAnswerParams(
        postId: widget.post.id,
        content: sanitized,
        // TARJIMA QILINMAYDI: bu qiymatlar wire/cache shakliga boradi,
        // UI yorlig'i emas. Ko'rsatishda `answerAuthorRoleLabel()` ishlaydi.
        authorName: asExpert ? "Ekspert Yurist" : "Fuqaro",
        isExpert: asExpert,
        authorRole: asExpert ? "Litsenziyaga ega advokat" : "Jamoat a'zosi",
      ),
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureText(context.l10n, failure)),
            // O'LCHANGAN: `crimson` (#EF4444) OQ matn ostida 3.76:1 —
            // xato xabari uchun AA (4.5:1) dan past. `emergencyStrong`
            // (#B91C1C) 6.47:1. Matn rangi endi `snackBarTheme` da qulflangan.
            backgroundColor: AppColors.emergencyStrong,
          ),
        );
      },
      (newAnswer) {
        setState(() {
          _answers.add(newAnswer);
          _answerController.clear();
        });

        // Parent'ga SO'RALGAN emas, DB'da REAL SAQLANGAN holat beriladi.
        widget.onAddAnswer?.call(sanitized, newAnswer.isExpert);

        // YOLG'ON SUCCESS'ni yopish: `enforce_expert_answer` triggeri
        // `is_expert_answer`ni JIMGINA `FALSE` ga tushirishi mumkin
        // (masalan, profil roli oradan o'zgargan bo'lsa). Bunday holatda
        // "muvaffaqiyatli" xabari haqiqatni YASHIRMASLIGI kerak.
        final demoted = asExpert && !newAnswer.isExpert;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(demoted
                ? context.l10n.answerSubmitDemoted
                : context.l10n.answerSubmitSuccess),
            // O'LCHANGAN: OQ matn `amber` ustida 2.15:1, `emerald` ustida
            // 2.54:1 edi — ya'ni "muvaffaqiyatli/pasaytirildi" xabari
            // deyarli O'QILMASDI. `amberStrong` 5.02:1, `emeraldStrong`
            // 7.68:1.
            backgroundColor:
                demoted ? AppColors.amberStrong : AppColors.emeraldStrong,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Future<void> _voteAnswer(QuestionAnswer answer) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      AskCommunityDialog.showAuthRequiredDialog(context,
          actionText: context.l10n.authActionVote);
      return;
    }

    final voteUseCase = sl<VoteCommunityAnswerUseCase>();
    final result = await voteUseCase(answer.id);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureText(context.l10n, failure)), backgroundColor: AppColors.emergencyStrong),
        );
      },
      (updatedAnswer) {
        setState(() {
          _answers = _answers.map((a) {
            return a.id == updatedAnswer.id ? updatedAnswer : a;
          }).toList();
        });
      },
    );
  }

  Future<void> _acceptAnswer(QuestionAnswer answer) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      AskCommunityDialog.showAuthRequiredDialog(context,
          actionText: context.l10n.authActionAcceptAnswer);
      return;
    }

    final acceptUseCase = sl<AcceptCommunityAnswerUseCase>();
    final result = await acceptUseCase(
      AcceptCommunityAnswerParams(
        questionId: widget.post.id,
        answerId: answer.id,
      ),
    );

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureText(context.l10n, failure)), backgroundColor: AppColors.emergencyStrong),
        );
      },
      (_) {
        setState(() {
          _answers = _answers.map((a) {
            return a.copyWith(isAccepted: a.id == answer.id);
          }).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.answerAcceptSuccess),
            backgroundColor: AppColors.emeraldStrong,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final post = widget.post;
    final formattedDate = DateFormat('dd.MM.yyyy, HH:mm').format(post.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.questionDetailTitle,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category & Date & Privacy Badge
                  Row(
                    children: [
                      // O'LCHANGAN: chip qorong'ida `indigo` ni O'ZINING
                      // `indigo@0.2` tinti ustida yozardi — 3.16:1, 12 px
                      // qalin matn uchun AA 4.5:1 kerak. Endi `AppTone`:
                      // 7.08:1 (qorong'i), 13.89:1 (yorug'). `Flexible` +
                      // ellipsis: inglizcha uzun kategoriya nomi bilan bu
                      // Row `Spacer` va sana bilan birga overflow berardi.
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs - 2),
                          decoration: BoxDecoration(
                            color: AppTone.accentIndigo.bg(isDark),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            border: Border.all(
                                color: AppTone.accentIndigo.border(isDark)),
                          ),
                          child: Text(
                            categoryLabel(l10n, post.category),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTone.accentIndigo.on(isDark),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const Gap(AppSpacing.sm),
                      // O'LCHANGAN: qo'lda qurilgan 10 px belgi edi va
                      // yorug'da `emeraldDark`+`emeraldLight` = 3.32:1
                      // berardi. `StatusBadge` 11 px polini va AYNI tondan
                      // olingan fon/chegara/matnni majburlaydi (6.73 / 7.03).
                      if (post.isAnonymous)
                        StatusBadge(
                          label: l10n.communityAnonymousShort,
                          tone: AppTone.success,
                          icon: Icons.lock_outline_rounded,
                          dense: true,
                        ),
                      const Spacer(),
                      Text(formattedDate, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                    ],
                  ),

                  const Gap(14),

                  // Question Title
                  Text(
                    post.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),

                  const Gap(10),

                  // Full Question Body
                  ModernContainer(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      post.anonymizedQuestion,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),

                  const Gap(16),

                  // Kategoriya bo'yicha avtomatik eslatma kartasi.
                  //
                  // HALOLLIK: `post.aiSummary` `ai_summary` ustunidan keladi,
                  // unga savol yaratilganda KATEGORIYA SHABLONI yoziladi
                  // (`community_forum_remote_datasource.dart`) — model
                  // chaqirilmaydi. Shu sababli uchqun piktogrammasi emas,
                  // deterministik `Icons.rule_rounded` ishlatiladi.
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md + 2),
                    decoration: BoxDecoration(
                      // O'LCHANGAN: qorong'ida sarlavha `indigo` `cardDark`
                      // ustida 3.27:1, yorug'da ikonka `indigo` tint ustida
                      // 4.20:1 edi. Endi fon/chegara/matn AYNI tondan:
                      // 7.34:1 (qorong'i), 16.77:1 matn + 5.91:1 ikonka.
                      color: AppTone.accentIndigo.bg(isDark),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border:
                          Border.all(color: AppTone.accentIndigo.border(isDark)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.rule_rounded,
                                color: AppTone.accentIndigo.on(isDark),
                                size: AppIconSize.sm),
                            const Gap(AppSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.questionDetailAiSummary,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTone.accentIndigo.on(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Gap(AppSpacing.sm),
                        Text(
                          post.aiSummary,
                          style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                        ),
                      ],
                    ),
                  ),

                  const Gap(24),

                  // Section Title: Answers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.questionDetailAnswersSection(_answers.length),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),

                  const Gap(12),

                  if (_answers.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            // O'LCHANGAN: ikonka IKKI mavzuda ham
                            // `textMutedLight` edi — `backgroundDark` ustida
                            // 3.70:1 (grafik minimumidan sal yuqori). Endi
                            // mavzuga bog'liq: 6.87:1.
                            Icon(Icons.forum_outlined,
                                size: AppIconSize.empty - 8,
                                color: isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMutedLight),
                            const Gap(8),
                            Text(
                              l10n.questionDetailEmptyAnswers,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _answers.length,
                      separatorBuilder: (_, __) => const Gap(12),
                      itemBuilder: (context, index) {
                        final answer = _answers[index];
                        return _buildAnswerCard(
                            context, answer, isDark, l10n);
                      },
                    ),
                ],
              ),
            ),
          ),

          // Bottom Reply Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Faqat REAL tasdiqlangan yurist/ekspert ko'radi.
                      if (_canAnswerAsExpert)
                        FilterChip(
                          selected: _isExpertReply,
                          label: Text(l10n.answerAsLawyerChip,
                              // `RawChip` yorliqni o'lchangan kengligiga TENG
                              // `maxWidth` bilan qayta layout qiladi va
                              // `TextOverflow.fade` ni majburlaydi — oxirgi
                              // glif so'nadi. Yorliq ARB'dan (qat'iy matn).
                              overflow: TextOverflow.visible,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _isExpertReply
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: _isExpertReply
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                              )),
                          // O'LCHANGAN: tanlanmagan holatda avatar ikonkasi
                          // `AppColors.primary` (#0F172A) edi va qorong'i
                          // mavzuda panel foni AYNI `surfaceDark` (#0F172A) —
                          // 1.00:1, ya'ni ikonka MUTLAQO ko'rinmasdi.
                          // Tanlangan fon ham `indigo` bo'lsa oq yorliq
                          // 4.47:1 berardi (12 px qalin matn "katta" emas),
                          // shuning uchun `indigoDark`: 6.29:1.
                          selectedColor:
                              isDark ? AppColors.indigoDark : AppColors.primary,
                          checkmarkColor: Colors.white,
                          avatar: Icon(
                            _isExpertReply ? Icons.gavel_rounded : Icons.person_outline_rounded,
                            size: AppIconSize.xs,
                            color: _isExpertReply
                                ? Colors.white
                                : AppTone.accentIndigo.on(isDark),
                          ),
                          onSelected: (val) {
                            setState(() {
                              _isExpertReply = val;
                            });
                          },
                        ),
                      const Spacer(),
                      // O'LCHANGAN: shrift 9 px edi (loyihadagi poli 11 px)
                      // va yorug'da `emeraldDark` oq ustida 3.77:1 berardi —
                      // MAXFIYLIK eslatmasi eng past kontrastli matn edi.
                      // Endi `AppTone.success.on()`: 7.68:1 / 9.29:1.
                      // `Flexible` + 2 qator: 11 px da bu matn `Row` ni
                      // chip bilan birga to'ldirib overflow berardi.
                      Flexible(
                        child: Text(
                          l10n.communityPiiNotice,
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTone.success.on(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _answerController,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: l10n.answerInputHint,
                            hintStyle: theme.textTheme.bodySmall,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Gap(8),
                      IconButton.filled(
                        onPressed: _isSubmitting ? null : _submitAnswer,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        style: IconButton.styleFrom(
                          // O'LCHANGAN: OQ "yuborish" ikonkasi `emerald`
                          // ustida 2.54:1 berardi (grafik minimumi 3:1) va
                          // qorong'ida `primary` fon panel foni bilan AYNI
                          // (#0F172A) — tugma yuzasi ko'rinmasdi. Endi:
                          // yorug' `emeraldStrong` 7.68:1 / `primary` 17.85:1,
                          // qorong'i `emeraldDark` 3.77:1 / `indigo` 4.47:1,
                          // yuza chegarasi esa 4.74:1 / 4.00:1.
                          backgroundColor: _isExpertReply
                              ? (isDark
                                  ? AppColors.emeraldDark
                                  : AppColors.emeraldStrong)
                              : (isDark ? AppColors.indigo : AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(
      BuildContext context, QuestionAnswer answer, bool isDark, AppL10n l10n) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd.MM.yyyy, HH:mm').format(answer.createdAt);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        // Qabul qilingan javob foni/chegarasi endi `AppTone.success` dan
        // (ilgari yorug'da `emeraldLight@0.3`, chegara `emerald@0.5` — matn
        // rangi bilan bir tondan EMAS edi).
        color: answer.isAccepted
            ? AppTone.success.bg(isDark)
            : (isDark ? AppColors.cardDark : Colors.white),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: answer.isAccepted
              ? AppTone.success.border(isDark)
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Row(
            children: [
              // O'LCHANGAN: ekspert avatari ikonkasi `emerald` edi — oq karta
              // ustida 2.54:1 (grafik minimumi 3:1 dan past). Oddiy
              // foydalanuvchi ikonkasi esa `textSecondaryLight` bo'lib IKKI
              // mavzuda qotib qolgan edi va `surfaceDark` ustida 2.40:1
              // berardi. Endi ikkisi ham ton bo'yicha: 6.36 / 5.41 va
              // neytral tonda 11+.
              CircleAvatar(
                radius: 16,
                backgroundColor: answer.isExpert
                    ? AppTone.success.bg(isDark, alpha: 0.20)
                    : AppTone.neutral.bg(isDark),
                child: Icon(
                  answer.isExpert ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                  size: AppIconSize.sm,
                  color: answer.isExpert
                      ? AppTone.success.on(isDark)
                      : AppTone.neutral.on(isDark),
                ),
              ),
              const Gap(AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            answer.authorName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (answer.isExpert) ...[
                          const Gap(AppSpacing.xxs),
                          // O'LCHANGAN: `emerald` oq karta ustida 2.54:1 edi.
                          Icon(Icons.verified_rounded,
                              size: AppIconSize.xs,
                              color: AppTone.success.on(isDark)),
                        ],
                      ],
                    ),
                    Text(
                      answerAuthorRoleLabel(l10n, answer.authorRole),
                      style: theme.textTheme.bodySmall?.copyWith(
                        // O'LCHANGAN: ekspert roli matni `emerald` edi —
                        // yorug'da 2.54:1. Endi 6.99–7.68:1 (yorug'),
                        // 5.84–7.61:1 (qorong'i).
                        color: answer.isExpert
                            ? AppTone.success.on(isDark)
                            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(dateStr, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
            ],
          ),

          const Gap(12),

          // Answer Body
          Text(
            answer.content,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),

          // Legal References
          if (answer.legalReferences.isNotEmpty) ...[
            const Gap(10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: answer.legalReferences.map((ref) {
                return InkWell(
                  onTap: () async {
                    final uri = Uri.parse("https://lex.uz");
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      // O'LCHANGAN: havola yorlig'i `indigo` ni O'ZINING
                      // tinti ustida yozardi — qorong'ida 2.80:1, yorug'da
                      // 3.79:1 (10 px w600 matn uchun AA 4.5:1 kerak).
                      // Endi 6.27:1 / 5.33:1.
                      color: AppTone.accentIndigo.bg(isDark),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      border: Border.all(
                          color: AppTone.accentIndigo.border(isDark)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_rounded,
                            size: 12, color: AppTone.accentIndigo.on(isDark)),
                        const Gap(AppSpacing.xxs),
                        Text(
                          ref,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTone.accentIndigo.on(isDark),
                              fontWeight: FontWeight.w600),
                        ),
                        const Gap(2),
                        Icon(Icons.open_in_new_rounded,
                            size: 10, color: AppTone.accentIndigo.on(isDark)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const Gap(12),

          // Footer: Accepted badge & Upvote button
          Row(
            children: [
              // O'LCHANGAN: "qabul qilindi" belgisi to'ldirilgan `emerald`
              // fon + OQ matn edi — 2.54:1, ya'ni eng muhim tasdiq belgisi
              // deyarli o'qilmasdi. `StatusBadge` (tint fon + AYNI tondan
              // matn): 6.73:1 / 7.03:1.
              if (answer.isAccepted)
                StatusBadge(
                  label: l10n.answerAcceptedBadge,
                  tone: AppTone.success,
                  icon: Icons.check_circle_rounded,
                  dense: true,
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _acceptAnswer(answer),
                  icon: const Icon(Icons.check_rounded, size: AppIconSize.xs),
                  label: Text(l10n.answerAcceptAction,
                      style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs - 2),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  answer.isUpvotedByMe ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                  size: AppIconSize.xs + 2,
                  // Bosilgan holat qorong'ida `indigo` `cardDark` ustida
                  // 3.27:1 edi — grafik uchun o'tadi, lekin AYNI ekranda
                  // boshqa aksentlar bilan bir xil bo'lishi uchun ton.
                  color: answer.isUpvotedByMe
                      ? AppTone.accentIndigo.on(isDark)
                      : null,
                ),
                onPressed: () => _voteAnswer(answer),
              ),
              Text("${answer.upvotesCount}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/role_labels.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';
import 'package:lexhub/core/theme/modern_container.dart';
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
          .from('profiles')
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
            backgroundColor: AppColors.crimson,
            behavior: SnackBarBehavior.floating,
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
            backgroundColor: demoted ? AppColors.amber : AppColors.emerald,
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
          SnackBar(content: Text(failureText(context.l10n, failure)), backgroundColor: AppColors.crimson),
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
          SnackBar(content: Text(failureText(context.l10n, failure)), backgroundColor: AppColors.crimson),
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
            backgroundColor: AppColors.emerald,
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.indigo.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          categoryLabel(l10n, post.category),
                          style: TextStyle(
                            color: isDark ? AppColors.indigo : AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Gap(8),
                      if (post.isAnonymous)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.emeraldDarkBg : AppColors.emeraldLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 12, color: isDark ? AppColors.emerald : AppColors.emeraldDark),
                              const Gap(4),
                              Text(l10n.communityAnonymousShort,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppColors.emerald : AppColors.emeraldDark)),
                            ],
                          ),
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

                  // AI Summary Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : AppColors.indigoLight.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.indigo.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: AppColors.indigo, size: 18),
                            const Gap(8),
                            Text(
                              l10n.questionDetailAiSummary,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.indigo : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const Gap(8),
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
                            const Icon(Icons.forum_outlined, size: 40, color: AppColors.textMutedLight),
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
                              style: const TextStyle(fontSize: 11)),
                          avatar: Icon(
                            _isExpertReply ? Icons.gavel_rounded : Icons.person_outline_rounded,
                            size: 14,
                            color: _isExpertReply ? Colors.white : AppColors.primary,
                          ),
                          onSelected: (val) {
                            setState(() {
                              _isExpertReply = val;
                            });
                          },
                        ),
                      const Spacer(),
                      Text(
                        l10n.communityPiiNotice,
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? AppColors.emerald : AppColors.emeraldDark,
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
                          backgroundColor: _isExpertReply ? AppColors.emerald : AppColors.primary,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: answer.isAccepted
            ? (isDark ? AppColors.emeraldDarkBg : AppColors.emeraldLight.withValues(alpha: 0.3))
            : (isDark ? AppColors.cardDark : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: answer.isAccepted
              ? AppColors.emerald.withValues(alpha: 0.5)
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: answer.isExpert
                    ? AppColors.emerald.withValues(alpha: 0.2)
                    : (isDark ? AppColors.surfaceDark : const Color(0xFFE2E8F0)),
                child: Icon(
                  answer.isExpert ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                  size: 18,
                  color: answer.isExpert ? AppColors.emerald : AppColors.textSecondaryLight,
                ),
              ),
              const Gap(10),
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
                          const Gap(4),
                          const Icon(Icons.verified_rounded, size: 14, color: AppColors.emerald),
                        ],
                      ],
                    ),
                    Text(
                      answerAuthorRoleLabel(l10n, answer.authorRole),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: answer.isExpert
                            ? AppColors.emerald
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.indigo.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark ? AppColors.indigo.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book_rounded, size: 11, color: AppColors.indigo),
                        const Gap(4),
                        Text(
                          ref,
                          style: const TextStyle(fontSize: 10, color: AppColors.indigo, fontWeight: FontWeight.w600),
                        ),
                        const Gap(2),
                        const Icon(Icons.open_in_new_rounded, size: 9, color: AppColors.indigo),
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
              if (answer.isAccepted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emerald,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 12, color: Colors.white),
                      const Gap(4),
                      Text(l10n.answerAcceptedBadge,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _acceptAnswer(answer),
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: Text(l10n.answerAcceptAction,
                      style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  answer.isUpvotedByMe ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                  size: 16,
                  color: answer.isUpvotedByMe ? AppColors.indigo : null,
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

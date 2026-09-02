import 'package:equatable/equatable.dart';
import 'package:lexhub/features/community_forum/domain/entities/question_answer.dart';

class CommunityPost extends Equatable {
  /// `ai_summary` ustuniga yoziladigan KATEGORIYA IZOHI — yagona manba.
  ///
  /// NIMA UCHUN BU YERDA: matn ilgari IKKI joyda alohida yozilgan edi
  /// (`community_forum_remote_datasource.dart` bazaga YOZADI,
  /// `ask_community_dialog.dart` esa optimistik postda KO'RSATADI) va allaqachon
  /// bir-biridan ajralib ketgan ("amaldagi" so'zi faqat bittasida bor edi).
  ///
  /// NIMA UCHUN KAFOLAT YO'Q: 2026-08-30 gacha bu matn "Fuqaroning huquqlari
  /// qonunchilik bilan kafolatlangan" degan gap bilan tugardi. Bu MANBASIZ
  /// huquqiy kafolat edi: birorta modda keltirilmagan, `ai_summary` ustuni
  /// orqali BAZAGA saqlanardi va barcha foydalanuvchilarga ko'rsatilardi
  /// (`.claude/skills/lexhub-legal-answer-safety` §1, §3). Qolgan gap — savol
  /// qaysi kategoriyaga tushganini aytadigan FAKT, huquqiy da'vo emas.
  ///
  /// TARJIMA QILINMAYDI (ARB'da emas): qiymat `questions.ai_summary` ustuniga
  /// yozilib BARCHA foydalanuvchilarga bir xil qaytadi, ya'ni o'quvchining
  /// tiliga bog'liq emas. Ko'rinadigan YORLIQ esa ARB'dan keladi va u bu
  /// matnni ataylab "AI xulosasi" deb NOMLAMAYDI
  /// (`community_post_card.dart:42`).
  static String categoryRoutingNote(String category) =>
      "Ushbu savol $category doirasida ko'rib chiqiladi.";

  final String id;
  final String? userId;
  final String title;
  final String anonymizedQuestion;
  final String category;
  final String aiSummary;
  final int helpfulCount;
  final int viewsCount;
  final int answersCount;
  final bool isAnonymous;
  final String authorName;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final bool isLikedByMe;
  final List<QuestionAnswer> answers;

  const CommunityPost({
    required this.id,
    this.userId,
    required this.title,
    required this.anonymizedQuestion,
    required this.category,
    required this.aiSummary,
    this.helpfulCount = 0,
    this.viewsCount = 0,
    this.answersCount = 0,
    this.isAnonymous = false,
    this.authorName = "Fuqaro",
    this.authorAvatarUrl,
    required this.createdAt,
    this.isLikedByMe = false,
    this.answers = const [],
  });

  CommunityPost copyWith({
    String? id,
    String? userId,
    String? title,
    String? anonymizedQuestion,
    String? category,
    String? aiSummary,
    int? helpfulCount,
    int? viewsCount,
    int? answersCount,
    bool? isAnonymous,
    String? authorName,
    String? authorAvatarUrl,
    DateTime? createdAt,
    bool? isLikedByMe,
    List<QuestionAnswer>? answers,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      anonymizedQuestion: anonymizedQuestion ?? this.anonymizedQuestion,
      category: category ?? this.category,
      aiSummary: aiSummary ?? this.aiSummary,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      viewsCount: viewsCount ?? this.viewsCount,
      answersCount: answersCount ?? this.answersCount,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      createdAt: createdAt ?? this.createdAt,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      answers: answers ?? this.answers,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        anonymizedQuestion,
        category,
        aiSummary,
        helpfulCount,
        viewsCount,
        answersCount,
        isAnonymous,
        authorName,
        authorAvatarUrl,
        createdAt,
        isLikedByMe,
        answers,
      ];
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_message.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_room.dart';
import 'package:lexhub/features/legal_talk/presentation/bloc/legal_talk_bloc.dart';
import 'package:lexhub/features/legal_talk/presentation/bloc/legal_talk_event.dart';
import 'package:lexhub/features/legal_talk/presentation/bloc/legal_talk_state.dart';
import 'package:lexhub/features/legal_talk/presentation/widgets/talk_message_bubble.dart';

class TalkRoomChatPage extends StatefulWidget {
  final TalkRoom room;

  const TalkRoomChatPage({
    super.key,
    required this.room,
  });

  @override
  State<TalkRoomChatPage> createState() => _TalkRoomChatPageState();
}

class _TalkRoomChatPageState extends State<TalkRoomChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _containsPii = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    final hasPii = PiiAnonymizer.containsPii(text);
    if (hasPii != _containsPii) {
      setState(() {
        _containsPii = hasPii;
      });
    }
  }

  void _sendMessage(BuildContext context) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    context.read<LegalTalkBloc>().add(
          SendTalkMessageEvent(
            roomId: widget.room.id,
            text: text,
            senderName: "Siz (Fuqaro)",
            senderRole: TalkSenderRole.citizen,
          ),
        );

    _messageController.clear();
    setState(() {
      _containsPii = false;
    });

    // Auto-scroll to bottom after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMockVoiceMessage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.indigo.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: isDark ? AppColors.indigo : AppColors.primary,
                  size: 36,
                ),
              ),
              const Gap(16),
              Text(
                "Ovozli savol yoki sharh yo'llash",
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Gap(6),
              Text(
                "Xabaringiz barcha ishtirokchilar va advokatlarga yetkaziladi",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const Gap(20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Bekor qilish"),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.read<LegalTalkBloc>().add(
                              SendTalkMessageEvent(
                                roomId: widget.room.id,
                                text: "Ovozli xabar: Savol bo'yicha audio izoh",
                                senderName: "Siz (Fuqaro)",
                                isAudio: true,
                                audioDuration: "0:35",
                              ),
                            );
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text("Yuborish (0:35)"),
                    ),
                  ),
                ],
              ),
              const Gap(12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocProvider(
      create: (context) => sl<LegalTalkBloc>()
        ..add(EnterTalkRoomChatEvent(widget.room)),
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.room.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        if (widget.room.isLive) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.crimson,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            "${widget.room.activeNowCount} faol onlayn",
                            style: TextStyle(
                              color: isDark ? AppColors.emergencyDark : AppColors.crimsonDark,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Gap(6),
                          Text(
                            "•",
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                          const Gap(6),
                        ],
                        Text(
                          widget.room.category,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: "Xona qoidalari",
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Munozara Xonasi Qoidalari"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.room.description,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                        const Gap(14),
                        const Text(
                          "1. O'zaro hurmat va madaniy muloqotga rioya qiling.\n"
                          "2. Barcha advokatlar rasmiy litsenziyaga ega.\n"
                          "3. Shaxsiy ma'lumotlar avtomat tozalanadi.",
                          style: TextStyle(fontSize: 12, height: 1.45),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Tushunarli"),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Top Pinned Room Topic Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cardDark
                    : AppColors.backgroundLight,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    size: 16,
                    color: isDark ? AppColors.indigo : AppColors.primary,
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      widget.room.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Messages Stream / List
            Expanded(
              child: BlocBuilder<LegalTalkBloc, LegalTalkState>(
                builder: (context, state) {
                  if (state is LegalTalkRoomChatLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is LegalTalkRoomChatLoaded) {
                    final messages = state.messages;

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return TalkMessageBubble(
                          message: msg,
                          onLikeTap: () {
                            context.read<LegalTalkBloc>().add(
                                  LikeTalkMessageEvent(
                                    roomId: widget.room.id,
                                    messageId: msg.id,
                                  ),
                                );
                          },
                        );
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),

            // Real-time PII Alert Banner when typing sensitive data
            if (_containsPii) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: isDark ? AppColors.amberDarkBg : AppColors.amberLight,
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: isDark ? AppColors.amber : AppColors.amberDark,
                    ),
                    const Gap(6),
                    Expanded(
                      child: Text(
                        "Privacy Guard: Kiritilayotgan raqamlar yuborilganda avtomat yashiriladi.",
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.amber : AppColors.amberDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Message Input Bar
            Builder(
              builder: (context) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.mic_rounded,
                            color: isDark ? AppColors.indigo : AppColors.primary,
                          ),
                          tooltip: "Ovozli xabar",
                          onPressed: () => _sendMockVoiceMessage(context),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            onChanged: _onTextChanged,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: "Huquqiy fikringiz yoki savolingiz...",
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? AppColors.cardDark
                                  : AppColors.backgroundLight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(context),
                          ),
                        ),
                        const Gap(8),
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isDark ? AppColors.indigo : AppColors.primary,
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                            onPressed: () => _sendMessage(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

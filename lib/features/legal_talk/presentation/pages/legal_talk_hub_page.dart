import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/legal_talk/presentation/bloc/legal_talk_bloc.dart';
import 'package:lexhub/features/legal_talk/presentation/bloc/legal_talk_event.dart';
import 'package:lexhub/features/legal_talk/presentation/bloc/legal_talk_state.dart';
import 'package:lexhub/features/legal_talk/presentation/pages/talk_room_chat_page.dart';
import 'package:lexhub/features/legal_talk/presentation/widgets/create_room_dialog.dart';
import 'package:lexhub/features/legal_talk/presentation/widgets/live_room_card.dart';
import 'package:lexhub/features/legal_talk/presentation/widgets/talk_room_list_item.dart';

class LegalTalkHubPage extends StatelessWidget {
  const LegalTalkHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = [
      "Barchasi",
      "Mehnat",
      "Haydovchilar",
      "Advokat bilan",
      "Uy-joy",
      "Erkin",
    ];

    return BlocProvider(
      create: (context) => sl<LegalTalkBloc>()..add(const LoadTalkRoomsEvent()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Legal Talk — Ochiq Minbar",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_comment_rounded),
              tooltip: "Yangi xona ochish",
              onPressed: () => CreateRoomDialog.show(context),
            ),
          ],
        ),
        body: BlocBuilder<LegalTalkBloc, LegalTalkState>(
          builder: (context, state) {
            if (state is LegalTalkRoomsLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is LegalTalkError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.emergency,
                        size: 44,
                      ),
                      const Gap(12),
                      Text(state.message, textAlign: TextAlign.center),
                      const Gap(16),
                      ElevatedButton(
                        onPressed: () => context
                            .read<LegalTalkBloc>()
                            .add(const LoadTalkRoomsEvent()),
                        child: const Text("Qayta urinish"),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is LegalTalkRoomsLoaded) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Community Banner
                    ModernContainer(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: isDark
                          ? AppColors.indigo.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.05),
                      borderColor: isDark
                          ? AppColors.indigo.withValues(alpha: 0.3)
                          : AppColors.primary.withValues(alpha: 0.15),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.indigo : AppColors.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.forum_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const Gap(14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Umumiy Munozaralar Xonasi",
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Gap(3),
                                Text(
                                  "Advokatlar va fuqarolar bilan real vaqtda jonli savol-javob hamda tajriba almashish maydoni.",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Gap(20),

                    // Live Rooms Section (Horizontal Carousel)
                    if (state.liveRooms.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.crimson,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Gap(8),
                          Text(
                            "Jonli Munozaralar (Hozir Efirda)",
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const Gap(12),
                      SizedBox(
                        height: 175,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: state.liveRooms.length,
                          separatorBuilder: (_, __) => const Gap(12),
                          itemBuilder: (context, index) {
                            final room = state.liveRooms[index];
                            return LiveRoomCard(
                              room: room,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TalkRoomChatPage(room: room),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const Gap(24),
                    ],

                    // Search and Filter Bar
                    TextField(
                      onChanged: (val) {
                        context.read<LegalTalkBloc>().add(SearchTalkRoomsEvent(val));
                      },
                      decoration: InputDecoration(
                        hintText: "Mavzular yoki advokatlar bo'yicha qidirish...",
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    const Gap(14),

                    // Category Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((cat) {
                          final isSelected = state.selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              selectedColor: isDark
                                  ? AppColors.indigo
                                  : AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 12,
                              ),
                              onSelected: (_) {
                                context
                                    .read<LegalTalkBloc>()
                                    .add(FilterTalkRoomsByCategoryEvent(cat));
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const Gap(18),

                    // All Discussion Rooms Header & Action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Barcha Munozara Xonalari (${state.filteredRooms.length})",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => CreateRoomDialog.show(context),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text("Xona ochish", style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),

                    const Gap(10),

                    // Room list
                    if (state.filteredRooms.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 40,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              ),
                              const Gap(10),
                              Text(
                                "Hech qanday munozara xonasi topilmadi",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.filteredRooms.length,
                        separatorBuilder: (_, __) => const Gap(12),
                        itemBuilder: (context, index) {
                          final room = state.filteredRooms[index];
                          return TalkRoomListItem(
                            room: room,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TalkRoomChatPage(room: room),
                                ),
                              );
                            },
                          );
                        },
                      ),

                    const Gap(32),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

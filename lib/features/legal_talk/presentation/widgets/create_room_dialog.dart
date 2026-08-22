import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/legal_talk/presentation/bloc/legal_talk_bloc.dart';
import 'package:lexhub/features/legal_talk/presentation/bloc/legal_talk_event.dart';

class CreateRoomDialog extends StatefulWidget {
  const CreateRoomDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider.value(
        value: context.read<LegalTalkBloc>(),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: const CreateRoomDialog(),
        ),
      ),
    );
  }

  @override
  State<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<CreateRoomDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = "Mehnat";

  final List<String> _categories = [
    "Mehnat",
    "Haydovchilar",
    "Advokat bilan",
    "Uy-joy",
    "Erkin",
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Iltimos, munozara mavzusini kiriting")),
      );
      return;
    }

    context.read<LegalTalkBloc>().add(
          CreateTalkRoomEvent(
            title: title,
            category: _selectedCategory,
            description: desc.isEmpty ? "Foydalanuvchilar tomonidan ochilgan munozara xonasi" : desc,
          ),
        );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Yangi munozara xonasi muvaffaqiyatli ochildi!"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
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
            const Gap(14),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.indigo.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.add_comment_rounded,
                    color: isDark ? AppColors.indigo : AppColors.primary,
                    size: 22,
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Yangi Munozara Xonasi",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        "Hamjamiyat va advokatlar bilan birga muhokama qiling",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Gap(16),

            // Category Selector
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(labelText: "Kategoriya"),
              dropdownColor: theme.colorScheme.surface,
              items: _categories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat,
                  child: Text(cat),
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

            const Gap(14),

            // Title Input
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Mavzu sarlavhasi *",
                hintText: "Masalan: Kredit foizlari oshishi qonuniymi?",
              ),
            ),

            const Gap(14),

            // Description Input
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Qisqacha tavsif (ixtiyoriy)",
                hintText: "Muhokama qilinadigan holat haqida qisqacha yozing...",
              ),
            ),

            const Gap(14),

            // Privacy reminder
            ModernContainer(
              padding: const EdgeInsets.all(12),
              backgroundColor: isDark ? AppColors.emeraldDarkBg : AppColors.emeraldLight,
              borderColor: isDark ? AppColors.emeraldDarkBorder : AppColors.emerald.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      "Privacy Guard: Xona sarlavhasi va tavsifidagi shaxsiy raqamlar avtomat tozalanadi.",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Gap(20),

            // Submit Button
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text("Munozara xonasini ochish"),
            ),

            const Gap(16),
          ],
        ),
      ),
    );
  }
}

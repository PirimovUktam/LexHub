import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/features/auth/data/repositories/profile_avatar_repository.dart';

class PrivateProfileAvatar extends StatefulWidget {
  const PrivateProfileAvatar(
      {super.key,
      required this.owner,
      required this.name,
      this.path,
      this.preview,
      this.radius = 40});
  final String owner;
  final String name;
  final String? path;
  final Uint8List? preview;
  final double radius;
  @override
  State<PrivateProfileAvatar> createState() => _PrivateProfileAvatarState();
}

class _PrivateProfileAvatarState extends State<PrivateProfileAvatar> {
  Future<Uint8List>? _image;
  void _load() {
    final path = widget.path;
    _image = path == null
        ? null
        : sl<ProfileAvatarRepository>().load(widget.owner, path);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PrivateProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.owner != widget.owner || oldWidget.path != widget.path) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallback = CircleAvatar(
        radius: widget.radius,
        backgroundColor: isDark ? AppColors.cardDark : AppColors.borderLight,
        child: Text(widget.name.characters.firstOrNull?.toUpperCase() ?? '',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color:
                    isDark ? AppColors.textPrimaryDark : AppColors.primary)));
    Widget photo(Uint8List data) => ClipOval(
        child: Image.memory(data,
            width: widget.radius * 2,
            height: widget.radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) => fallback));
    final preview = widget.preview;
    if (preview != null) return photo(preview);
    return FutureBuilder<Uint8List>(
        key: ValueKey('${widget.owner}/${widget.path}'),
        future: _image,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes != null) return photo(bytes);
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox.square(
                dimension: widget.radius * 2,
                child: const Center(child: CircularProgressIndicator()));
          }
          return fallback;
        });
  }
}

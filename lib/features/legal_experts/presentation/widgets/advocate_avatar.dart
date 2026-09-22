import 'dart:typed_data';

import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/advocate_profile_repository.dart';

class AdvocateAvatar extends StatefulWidget {
  const AdvocateAvatar(
      {super.key, required this.repository, this.path, this.preview});
  final AdvocateProfileRepository repository;
  final String? path;
  final Uint8List? preview;

  @override
  State<AdvocateAvatar> createState() => _AdvocateAvatarState();
}

class _AdvocateAvatarState extends State<AdvocateAvatar> {
  Future<Either<Failure, String>>? _url;

  void _load() {
    final path = widget.path;
    _url = path == null || path.isEmpty
        ? null
        : widget.repository.getSignedUrl(path);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AdvocateAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = AppIconSize.empty * 2;
    const fallback = CircleAvatar(
        radius: AppIconSize.empty,
        child: Icon(Icons.person_outline, size: AppIconSize.empty));
    final preview = widget.preview;
    if (preview != null) {
      return ClipOval(
          child: Image.memory(preview,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => fallback));
    }
    return FutureBuilder<Either<Failure, String>>(
      future: _url,
      builder: (context, snapshot) {
        final url = snapshot.data?.fold<String?>((_) => null, (url) => url);
        if (url == null) return fallback;
        return ClipOval(
            child: Image.network(url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => fallback));
      },
    );
  }
}

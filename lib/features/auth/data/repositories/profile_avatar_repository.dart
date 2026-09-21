import 'dart:typed_data';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/network/request_timeout.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Private objects are downloaded with the current session, never public URLs.
class ProfileAvatarRepository {
  ProfileAvatarRepository(this.client);
  final SupabaseClient client;
  static const bucket = 'user-avatars';
  static const maxBytes = 5 * 1024 * 1024;

  static String? imageExtension(Uint8List bytes) {
    if (bytes.length < 12 || bytes.length > maxBytes) return null;
    if (bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) return 'jpg';
    if (bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') return 'png';
    if (String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
      return 'webp';
    }
    return null;
  }

  void _check(String owner, [String? path]) {
    if (client.auth.currentUser?.id != owner ||
        (path != null &&
            !RegExp('^$owner/[0-9a-f-]{36}\\.(png|jpg|webp)\$')
                .hasMatch(path))) {
      throw ServerException(
          message: '', statusCode: 403, details: 'avatar_access_denied');
    }
  }

  Future<Uint8List> load(String owner, String path) async {
    _check(owner, path);
    final bytes = await client.storage
        .from(bucket)
        .download(path)
        .withTimeout(kDbRequestTimeout, label: 'avatar_download');
    _check(owner, path);
    return bytes;
  }

  Future<String> upload(String owner, Uint8List bytes) async {
    _check(owner);
    final extension = imageExtension(bytes);
    if (extension == null) {
      throw ServerException(
          message: '', statusCode: 400, details: 'invalid_avatar');
    }
    final path = '$owner/${const Uuid().v4()}.$extension';
    await client.storage
        .from(bucket)
        .uploadBinary(path, bytes,
            fileOptions: FileOptions(
                cacheControl: '0',
                contentType: 'image/${extension == 'jpg' ? 'jpeg' : extension}',
                upsert: false))
        .withTimeout(kDbRequestTimeout, label: 'avatar_upload');
    _check(owner, path);
    return path;
  }

  Future<void> remove(String owner, String path) async {
    _check(owner, path);
    await client.storage
        .from(bucket)
        .remove([path]).withTimeout(kDbRequestTimeout, label: 'avatar_remove');
  }
}

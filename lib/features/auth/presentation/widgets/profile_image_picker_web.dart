import 'dart:async';
import 'dart:js_interop';
import 'package:image_picker/image_picker.dart';
import 'package:lexhub/features/auth/data/repositories/profile_avatar_repository.dart';
import 'package:web/web.dart' as web;

/// Read the user-selected File in memory. XFile(path).readAsBytes uses an XHR
/// to a blob URL, which the production connect-src policy intentionally denies.
Future<XFile?> pickProfileImage() async {
  final result = Completer<web.File?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp'
    ..hidden = true.toJS;
  input.onchange = ((web.Event _) {
    if (!result.isCompleted) result.complete(input.files?.item(0));
  }).toJS;
  input.oncancel = ((web.Event _) {
    if (!result.isCompleted) result.complete(null);
  }).toJS;
  input.onerror = ((web.Event _) {
    if (!result.isCompleted) result.completeError(const FormatException());
  }).toJS;
  web.document.body?.append(input);
  try {
    input.click();
    final file = await result.future;
    if (file == null) return null;
    if (file.size > ProfileAvatarRepository.maxBytes) {
      throw const FormatException();
    }
    final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
    return XFile.fromData(bytes, name: file.name, mimeType: file.type);
  } finally {
    input.remove();
  }
}

void releaseProfileImage(XFile file) {
  if (file.path.startsWith('blob:')) web.URL.revokeObjectURL(file.path);
}

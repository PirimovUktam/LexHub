import 'package:image_picker/image_picker.dart';

Future<XFile?> pickProfileImage() => ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 90,
    requestFullMetadata: false);

void releaseProfileImage(XFile file) {}

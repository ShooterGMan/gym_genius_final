import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Stores progress photos inside the app's documents directory.
///
/// Only the *file name* is persisted: on iOS the absolute container path
/// changes between app updates, so absolute paths would break.
class PhotoStorage {
  static Future<Directory> directory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/progress_photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Opens camera / gallery, copies the image into app storage and returns
  /// the stored file name (or null if the user cancelled).
  static Future<String?> pickAndStore(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final dir = await directory();
    final name = '${const Uuid().v4()}.jpg';
    await File(picked.path).copy('${dir.path}/$name');
    return name;
  }

  /// Resolves a stored value (file name, or a legacy absolute path).
  static String resolve(String dirPath, String stored) {
    if (stored.contains('/') || stored.contains('\\')) {
      if (File(stored).existsSync()) return stored;
      final base = stored.split(RegExp(r'[\\/]')).last;
      return '$dirPath/$base';
    }
    return '$dirPath/$stored';
  }

  static Future<void> deleteFile(String stored) async {
    try {
      final dir = await directory();
      final f = File(resolve(dir.path, stored));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

final photoDirProvider = FutureProvider<String>((ref) async {
  return (await PhotoStorage.directory()).path;
});

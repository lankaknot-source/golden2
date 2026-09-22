import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  Future<String> uploadImage(
    File file,
    String folder, {
    int quality = 75,
    int maxWidth = 1080,
  }) async {
    final Uint8List bytes;
    // flutter_image_compress only works on Android/iOS/macOS
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: quality,
        minWidth: maxWidth,
      );
      bytes = compressed ?? await file.readAsBytes();
    } else {
      bytes = await file.readAsBytes();
    }
    final ext = p.extension(file.path).isNotEmpty ? p.extension(file.path) : '.jpg';
    final fileName = '${_uuid.v4()}$ext';
    final ref = _storage.ref('$folder/$fileName');
    final task = ref.putData(bytes);
    final snapshot = await task;
    return snapshot.ref.getDownloadURL();
  }

  Future<String> uploadFile(File file, String folder) async {
    final fileName = '${_uuid.v4()}_${p.basename(file.path)}';
    final ref = _storage.ref('$folder/$fileName');
    final task = ref.putFile(file);
    final snapshot = await task;
    return snapshot.ref.getDownloadURL();
  }

  Future<void> deleteFile(String downloadUrl) async {
    final ref = _storage.refFromURL(downloadUrl);
    await ref.delete();
  }

  Future<List<String>> uploadMultipleImages(
    List<File> files,
    String folder,
  ) async {
    final futures = files.map((f) => uploadImage(f, folder));
    return Future.wait(futures);
  }
}

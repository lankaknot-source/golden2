import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

/// Encodes attachments for Firestore instead of Firebase Storage.
class StorageService {
  Future<String> uploadImage(
    File file,
    String folder, {
    int quality = 70,
    int maxWidth = 1280,
  }) async {
    final compressed = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      quality: quality,
      minWidth: maxWidth,
      format: CompressFormat.jpeg,
    );
    final bytes = compressed ?? await file.readAsBytes();
    return _dataUrl(bytes, 'image/jpeg');
  }

  Future<String> uploadFile(File file, String folder) async {
    final ext = p.extension(file.path).toLowerCase();
    final isImage = {'.jpg', '.jpeg', '.png', '.webp', '.heic'}.contains(ext);
    if (isImage) return uploadImage(file, folder);
    final bytes = await file.readAsBytes();
    return _dataUrl(bytes, _mimeType(ext));
  }

  /// Firestore owns the data now; there is no remote Storage object to delete.
  Future<void> deleteFile(String downloadUrl) async {}

  Future<List<String>> uploadMultipleImages(
    List<File> files,
    String folder,
  ) async {
    final futures = files.map((f) => uploadImage(f, folder));
    return Future.wait(futures);
  }

  String _dataUrl(Uint8List bytes, String mimeType) =>
      'data:$mimeType;base64,${base64Encode(bytes)}';

  String _mimeType(String extension) => switch (extension) {
        '.pdf' => 'application/pdf',
        '.txt' => 'text/plain',
        '.doc' => 'application/msword',
        '.docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        _ => 'application/octet-stream',
      };
}

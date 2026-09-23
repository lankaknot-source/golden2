import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Supports both legacy Firebase Storage URLs and new Firestore data URLs.
ImageProvider<Object> storedImageProvider(String value) {
  if (value.startsWith('data:')) {
    try {
      final data = Uri.parse(value).data;
      if (data != null) return MemoryImage(Uint8List.fromList(data.contentAsBytes()));
    } catch (_) {
      // Fall through to NetworkImage so a malformed legacy value does not
      // crash the widget tree.
    }
  }
  return NetworkImage(value);
}

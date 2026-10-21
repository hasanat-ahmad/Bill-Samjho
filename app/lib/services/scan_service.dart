import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants.dart';

/// Gets a bill photo (FR-03) and compresses it for upload (FR-04).
class ScanService {
  final _picker = ImagePicker();

  /// Opens the ML Kit document scanner (auto crop, gallery import allowed).
  /// Falls back to the plain camera if the scanner is unavailable.
  /// Returns the image path, or null if the user cancelled.
  Future<String?> scan() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        mode: ScannerMode.full,
        pageLimit: 1,
        isGalleryImport: true,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      final images = result.images;
      return images == null || images.isEmpty ? null : images.first;
    } on PlatformException catch (e) {
      if (e.message == 'Operation cancelled') return null;
      debugPrint('Document scanner unavailable, using camera: $e');
      return _pick(ImageSource.camera);
    } finally {
      await scanner.close();
    }
  }

  Future<String?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<String?> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source);
    return file?.path;
  }

  /// (long edge px, JPEG quality) tried in order until the image fits.
  static const _attempts = [
    (AppConstants.imageLongEdgePx, AppConstants.imageQuality),
    (AppConstants.imageLongEdgePx, 65),
    (1280, 65),
    (1280, 50),
    (1024, 50),
  ];

  /// JPEG with long edge ≤ 1600 px and size ≤ 300 KB (FR-04).
  Future<Uint8List> compress(String path) async {
    final (width, height) = await _imageSize(path);
    Uint8List? last;
    for (final (longEdge, quality) in _attempts) {
      // The plugin scales so the image covers minWidth × minHeight; passing
      // the exact target size keeps the aspect ratio.
      final scale = (longEdge / (width > height ? width : height)).clamp(0.0, 1.0);
      last = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: (width * scale).round(),
        minHeight: (height * scale).round(),
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (last == null) break;
      if (last.length <= AppConstants.imageMaxBytes) return last;
    }
    if (last == null) throw Exception('Could not read image');
    return last;
  }

  static Future<(int, int)> _imageSize(String path) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = (descriptor.width, descriptor.height);
    descriptor.dispose();
    buffer.dispose();
    return size;
  }
}

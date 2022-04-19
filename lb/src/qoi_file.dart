import 'dart:typed_data';

class QoiFile {
  final int width;
  final int height;
  final Uint8List bytes;
  final bool withAlpha;
  final bool linearColorSpace;

  QoiFile(
    this.width,
    this.height,
    this.bytes,
    this.withAlpha,
    this.linearColorSpace,
  );
}
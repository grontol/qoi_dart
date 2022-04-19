import 'dart:io';
import 'package:qoi_dart/qoi_dart.dart';

void main() {
  final bytes1 =  File("/path/to/file.bin").readAsBytesSync();
  final encoded = qoiEncode(bytes1, 640, 480, PixelFormat.ARGB, true);
  File("/path/to/file.qoi").writeAsBytesSync(encoded);

  final bytes2 =  File("/path/to/file.qoi").readAsBytesSync();
  final decoded = qoiDecode(bytes2, PixelFormat.ARGB);
  File("/path/to/file.bin").writeAsBytesSync(decoded.bytes);
}

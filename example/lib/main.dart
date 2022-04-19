import 'dart:io';
import 'package:qoi_dart/qoi_dart.dart';

void main(List<String> arguments) async {
  final bytes1 =  await File("/path/to/file.bin").readAsBytes();
  final encoded = qoiEncode(bytes1, 640, 480, PixelFormat.ARGB, true);
  File("/path/to/file.qoi").writeAsBytesSync(encoded);

  final bytes2 =  await File("/path/to/file.qoi").readAsBytes();
  final decoded = qoiDecode(bytes2, PixelFormat.ARGB);
  File("/path/to/file.bin").writeAsBytesSync(decoded.bytes);
}

# qoi_dart

## Overview

A QOI image format encoder / decoder implemented purely in dart

## Example

Encoding

```dart
import 'dart:io';
import 'package:qoi_dart/qoi_dart.dart';

void main() {
  final bytes = File("/path/to/file.bin").readAsBytesSync();
  final encoded = qoiEncode(bytes, 640, 480, PixelFormat.ARGB, true);
  File("/path/to/file.qoi").writeAsBytesSync(encoded);
}
```

Decoding

```dart
import 'dart:io';
import 'package:qoi_dart/qoi_dart.dart';

void main() {
  final bytes = File("/path/to/file.qoi").readAsBytesSync();
  final decoded = qoiDecode(bytes, PixelFormat.ARGB);
  File("/path/to/file.bin").writeAsBytesSync(decoded.bytes);
}
```
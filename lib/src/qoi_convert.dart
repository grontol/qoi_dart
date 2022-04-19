import 'dart:typed_data';

import 'pixel_format.dart';
import 'qoi_file.dart';

const _QOI_OP_RGB = 0xFE;
const _QOI_OP_RGBA = 0xFF;
const _QOI_OP_INDEX = 0;
const _QOI_OP_DIFF = 1;
const _QOI_OP_LUMA = 2;
const _QOI_OP_RUN = 3;

/// Encode [Uint8List] with the given [PixelFormat] as an input pixel format
///
/// [PixelFormat] can be any of [PixelFormat.RGB] (0xRRGGBB),
/// [PixelFormat.ARGB] (0xAARRGGBB) or [PixelFormat.RGBA] (0xRRGGBBAA).
///
/// Returns a [Uint8List]
Uint8List qoiEncode(Uint8List bytes, int width, int height, PixelFormat pixelFormat, [bool linearColorSpace = true]) {
  if (width <= 0 || height <= 0 || height > 2147483625 / width / (pixelFormat == PixelFormat.RGB ? 4 : 5)) {
    throw "Cannot encode file";
  }

  bool hasAlpha = false;
  int inputChannel = (pixelFormat == PixelFormat.RGB ? 3 : 4);

  if (bytes.length != width * height * inputChannel) {
    throw "Width / height / pixelFormat doesn't match with number of bytes";
  }

  int readIndex = 0;

  int readColor() {
    if (pixelFormat == PixelFormat.RGB) {
      return bytes[readIndex++] << 24
      | bytes[readIndex++] << 16
      | bytes[readIndex++] << 8
      | 0xFF;
    }
    else if (pixelFormat == PixelFormat.RGBA) {
      return bytes[readIndex++] << 24
      | bytes[readIndex++] << 16
      | bytes[readIndex++] << 8
      | bytes[readIndex++];
    }
    else {
      return bytes[readIndex++]
      | bytes[readIndex++] << 24
      | bytes[readIndex++] << 16
      | bytes[readIndex++] << 8;
    }
  }

  final outBytes = Uint8List(14 + width * height * (pixelFormat == PixelFormat.RGB ? 4 : 5) + 8);
  int writeIndex = 0;

  void writeByte(int byte) {
    outBytes[writeIndex++] = byte;
  }

  void writeInt32(int i) {
    outBytes[writeIndex++] = (i & 0xFF000000) >> 24;
    outBytes[writeIndex++] = (i & 0x00FF0000) >> 16;
    outBytes[writeIndex++] = (i & 0x0000FF00) >> 8;
    outBytes[writeIndex++] = (i & 0x000000FF);
  }

  void writeColor(int r, int g, int b, int a) {
    outBytes[writeIndex++] = r & 0xFF;
    outBytes[writeIndex++] = g & 0xFF;
    outBytes[writeIndex++] = b & 0xFF;
    outBytes[writeIndex++] = a & 0xFF;
  }

  // Header ======================
  // =============================

  // qoif
  writeByte(113);
  writeByte(111);
  writeByte(105);
  writeByte(102);

  // Width & height
  writeInt32(width);
  writeInt32(height);

  // Channels & color space
  writeByte(0);
  writeByte(linearColorSpace ? 1 : 0);

  final pixelIndex = Int64List.fromList(List.filled(64, 0));

  int prevPixel = 0x000000FF;

  int run = 0;

  for (int i = 0; i < bytes.length; i += inputChannel) {
    int color = readColor();

    int r = (color & 0xFF000000) >> 24;
    int g = (color & 0x00FF0000) >> 16;
    int b = (color & 0x0000FF00) >> 8;
    int a = (color & 0x000000FF);

    if (color == prevPixel) {
      run++;

      if (run == 62 || readIndex == bytes.length) {
        writeByte((_QOI_OP_RUN << 6) | (run - 1));
        run = 0;
      }
    }
    else {
      if (run > 0) {
        writeByte((_QOI_OP_RUN << 6) | (run - 1));
        run = 0;
      }

      int index = (r * 3 + g * 5 + b * 7 + a * 11) % 64;

      if (color == pixelIndex[index]) {
        writeByte(index);
      }
      else {
        pixelIndex[index] = color & 0xFFFFFFFF;

        if (prevPixel & 0xFF != a) {
          hasAlpha = true;

          writeByte(_QOI_OP_RGBA);
          writeColor(r, g, b, a);
        }
        else {
          int dr = r - (prevPixel >> 24 & 255);
          int dg = g - (prevPixel >> 16 & 255);
          int db = b - (prevPixel >> 8 & 255);

          if (dr >= -2 && dr <= 1 && dg >= -2 && dg <= 1 && db >= -2 && db <= 1) {
            writeByte((_QOI_OP_DIFF << 6) | (dr + 2) << 4 | (dg + 2) << 2 | (db + 2));
          }
          else {
            dr -= dg;
            db -= dg;

            if (dr >= -8 && dr <= 7 && dg >= -32 && dg <= 31 && db >= -8 && db <= 7) {
              writeByte((_QOI_OP_LUMA << 6) | (dg + 32));
              writeByte((dr + 8) << 4 | (db + 8));
            }
            else {
              writeByte(_QOI_OP_RGB);
              writeByte(r);
              writeByte(g);
              writeByte(b);
            }
          }
        }
      }

      prevPixel = color;
    }
  }

  // Automatically set has alpha if the image contains alpha that is not 255
  outBytes[12] = hasAlpha ? 4 : 3;

  writeByte(0);
  writeByte(0);
  writeByte(0);
  writeByte(0);

  writeByte(0);
  writeByte(0);
  writeByte(0);
  writeByte(1);

  return outBytes.sublist(0, writeIndex);
}

/// Decode [Uint8List] to a [QoiFile] with the given [PixelFormat] as an output pixel format.
///
/// [PixelFormat] can be any of [PixelFormat.RGB] (0xRRGGBB),
/// [PixelFormat.ARGB] (0xAARRGGBB) or [PixelFormat.RGBA] (0xRRGGBBAA).
///
/// Returns a [QoiFile] with information such as width, height, etc.
QoiFile qoiDecode(Uint8List bytes, PixelFormat pixelFormat) {
  int readIndex = 0;

  int readByte() {
    return bytes[readIndex++];
  }

  int readInt32() {
    return readByte() << 24 | readByte() << 16 | readByte() << 8 | readByte();
  }

  if (bytes.length < 23 || readByte() != 113 || readByte() != 111 || readByte() != 105 || readByte() != 102) {
    throw "Invalid QOI file";
  }

  if (bytes[bytes.length - 1] != 1 || bytes[bytes.length - 2] != 0
      ||  bytes[bytes.length - 3] != 0||  bytes[bytes.length - 4] != 0
      ||  bytes[bytes.length - 5] != 0||  bytes[bytes.length - 6] != 0
      ||  bytes[bytes.length - 7] != 0||  bytes[bytes.length - 8] != 0) {
    throw "Invalid QOI file";
  }

  int width = readInt32();
  int height = readInt32();

  if (width <= 0 || height <= 0 || height > 2147483647 / width) {
    throw "Invalid width / height";
  }

  int channels = readByte();
  bool hasAlpha = false;

  if (channels == 3) {
  }
  else if (channels == 4) {
    hasAlpha = true;
  }
  else {
    throw "Invalid channels";
  }

  int colorSpace = readByte();
  bool linearColorSpace = false;

  if (colorSpace == 0) {
  }
  else if (colorSpace == 1) {
    linearColorSpace = true;
  }
  else {
    throw "Invalid color space";
  }

  final outChannels = pixelFormat == PixelFormat.RGB ? 3 : 4;
  final outBytes = Uint8List(width * height * outChannels);
  int writeIndex = 0;

  final pixelIndex = Int64List.fromList(List.filled(64, 0));
  int prevPixelR = 0;
  int prevPixelG = 0;
  int prevPixelB = 0;
  int prevPixelA = 255;

  void writeColor(int r, int g, int b, int a) {
    if (pixelFormat == PixelFormat.RGBA) {
      outBytes[writeIndex++] = r & 0x000000FF;
      outBytes[writeIndex++] = g & 0x000000FF;
      outBytes[writeIndex++] = b & 0x000000FF;
      outBytes[writeIndex++] = a & 0x000000FF;
    }
    else if (pixelFormat == PixelFormat.ARGB) {
      outBytes[writeIndex++] = a & 0x000000FF;
      outBytes[writeIndex++] = r & 0x000000FF;
      outBytes[writeIndex++] = g & 0x000000FF;
      outBytes[writeIndex++] = b & 0x000000FF;
    }
    else {
      outBytes[writeIndex++] = r & 0x000000FF;
      outBytes[writeIndex++] = g & 0x000000FF;
      outBytes[writeIndex++] = b & 0x000000FF;
    }
  }

  while (readIndex < bytes.length - 8) {
    int op = readByte();

    if (op == _QOI_OP_RGB) {
      int r = readByte();
      int g = readByte();
      int b = readByte();
      int a = prevPixelA;

      writeColor(r, g, b, a);

      prevPixelR = r;
      prevPixelG = g;
      prevPixelB = b;
      prevPixelA = a;
      pixelIndex[(r * 3 + g * 5 + b * 7 + a * 11) % 64] = r << 24 | g << 16 | b << 8 | a;
    }
    else if (op == _QOI_OP_RGBA) {
      int r = readByte();
      int g = readByte();
      int b = readByte();
      int a = readByte();

      writeColor(r, g, b, a);

      prevPixelR = r;
      prevPixelG = g;
      prevPixelB = b;
      prevPixelA = a;
      pixelIndex[(r * 3 + g * 5 + b * 7 + a * 11) % 64] = r << 24 | g << 16 | b << 8 | a;
    }
    else if (op >> 6 == _QOI_OP_INDEX) {
      int index = op & 0x3F;
      int color = pixelIndex[index];

      int r = (color & 0xFF000000) >> 24;
      int g = (color & 0x00FF0000) >> 16;
      int b = (color & 0x0000FF00) >> 8;
      int a = (color & 0x000000FF);

      writeColor(r, g, b, a);

      prevPixelR = r;
      prevPixelG = g;
      prevPixelB = b;
      prevPixelA = a;
    }
    else if (op >> 6 == _QOI_OP_DIFF) {
      int r = (prevPixelR + ((op & 0x30) >> 4) - 2) % 256;
      int g = (prevPixelG + ((op & 0x0C) >> 2) - 2) % 256;
      int b = (prevPixelB + (op & 0x03) - 2) % 256;
      int a = prevPixelA;

      writeColor(r, g, b, a);

      prevPixelR = r;
      prevPixelG = g;
      prevPixelB = b;
      prevPixelA = a;
      pixelIndex[(r * 3 + g * 5 + b * 7 + a * 11) % 64] = r << 24 | g << 16 | b << 8 | a;
    }
    else if (op >> 6 == _QOI_OP_LUMA) {
      int byte = readByte();

      int dg = (op & 0x3F) - 32;
      int dr = ((byte & 0xF0) >> 4) + dg;
      int db = (byte & 0x0F) + dg;

      int r = (prevPixelR + dr - 8) % 256;
      int g = (prevPixelG + dg) % 256;
      int b = (prevPixelB + db - 8) % 256;
      int a = prevPixelA;

      writeColor(r, g, b, a);

      prevPixelR = r;
      prevPixelG = g;
      prevPixelB = b;
      prevPixelA = a;
      pixelIndex[(r * 3 + g * 5 + b * 7 + a * 11) % 64] = r << 24 | g << 16 | b << 8 | a;
    }
    else if (op >> 6 == _QOI_OP_RUN) {
      int run = (op & 0x3F) + 1;

      for (int a = 0; a < run; a++) {
        writeColor(prevPixelR, prevPixelG, prevPixelB, prevPixelA);
      }
    }
  }

  return QoiFile(width, height, outBytes, hasAlpha, linearColorSpace);
}
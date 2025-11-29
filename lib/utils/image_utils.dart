import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

class ImageUtils {
  static Future<List<double>> processCameraImage(CameraImage image) async {
    // We need to copy data to pass to isolate because CameraImage contains pointers
    // However, copying might be expensive too. 
    // For simplicity in this step, let's extract the necessary data.
    
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
    
    // Copy bytes to avoid native pointer issues in Isolate
    final yBytes = Uint8List.fromList(image.planes[0].bytes);
    final uBytes = Uint8List.fromList(image.planes[1].bytes);
    final vBytes = Uint8List.fromList(image.planes[2].bytes);

    return compute(_processInIsolate, _IsolateData(
      width: width,
      height: height,
      uvRowStride: uvRowStride,
      uvPixelStride: uvPixelStride,
      yBytes: yBytes,
      uBytes: uBytes,
      vBytes: vBytes,
      inputSize: 640,
    ));
  }

  static List<double> _processInIsolate(_IsolateData data) {
    // YUV conversion
    var imgBuffer = img.Image(width: data.width, height: data.height);

    for (int x = 0; x < data.width; x++) {
      for (int y = 0; y < data.height; y++) {
        final int uvIndex =
            data.uvPixelStride * (x / 2).floor() + data.uvRowStride * (y / 2).floor();
        final int index = y * data.width + x;

        final yp = data.yBytes[index];
        final up = data.uBytes[uvIndex];
        final vp = data.vBytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        imgBuffer.setPixelRgb(x, y, r, g, b);
      }
    }

    // Letterbox resize to preserve aspect ratio
    // Calculate scaling to fit within 640x640 while maintaining aspect ratio
    final double scale = (data.width > data.height) 
        ? data.inputSize / data.width 
        : data.inputSize / data.height;
    
    final int newWidth = (data.width * scale).round();
    final int newHeight = (data.height * scale).round();
    
    // Resize maintaining aspect ratio
    final resized = img.copyResize(imgBuffer, width: newWidth, height: newHeight);
    
    // Create 640x640 canvas with padding (letterbox)
    final canvas = img.Image(width: data.inputSize, height: data.inputSize);
    
    // Fill with gray (114, 114, 114) - standard YOLO padding color
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));
    
    // Calculate padding offsets to center the image
    final int offsetX = ((data.inputSize - newWidth) / 2).round();
    final int offsetY = ((data.inputSize - newHeight) / 2).round();
    
    // Composite resized image onto canvas
    img.compositeImage(canvas, resized, dstX: offsetX, dstY: offsetY);
    
    // Normalize and convert to Float32List
    final Float32List floatList = Float32List(1 * 3 * data.inputSize * data.inputSize);
    int pixelIndex = 0;
    
    for (var c = 0; c < 3; c++) {
      for (var y = 0; y < data.inputSize; y++) {
        for (var x = 0; x < data.inputSize; x++) {
          final pixel = canvas.getPixel(x, y);
          double val = 0;
          if (c == 0) val = pixel.r / 255.0;
          if (c == 1) val = pixel.g / 255.0;
          if (c == 2) val = pixel.b / 255.0;
          
          floatList[pixelIndex++] = val;
        }
      }
    }
    return floatList;
  }
}

class _IsolateData {
  final int width;
  final int height;
  final int uvRowStride;
  final int uvPixelStride;
  final Uint8List yBytes;
  final Uint8List uBytes;
  final Uint8List vBytes;
  final int inputSize;

  _IsolateData({
    required this.width,
    required this.height,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.yBytes,
    required this.uBytes,
    required this.vBytes,
    required this.inputSize,
  });
}

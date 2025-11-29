import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/detection.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<Detection> detections;
  final Size imageSize;
  final CameraController cameraController;

  BoundingBoxPainter({
    required this.detections,
    required this.imageSize,
    required this.cameraController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 1. Get Camera Preview Dimensions
    // Note: Android camera preview is often rotated 90 degrees.
    // We use the aspect ratio from the controller which handles this.
    final double cameraAspectRatio = cameraController.value.aspectRatio;
    
    // 2. Calculate Screen Preview Area
    // The camera preview maintains its aspect ratio within the screen size.
    double previewWidth = size.width;
    double previewHeight = size.width / cameraAspectRatio;
    
    double screenOffsetX = 0;
    double screenOffsetY = 0;
    
    if (previewHeight > size.height) {
      // Preview is taller than screen, fit by height
      previewHeight = size.height;
      previewWidth = size.height * cameraAspectRatio;
      screenOffsetX = (size.width - previewWidth) / 2;
    } else {
      // Preview is shorter than screen, center vertically
      screenOffsetY = (size.height - previewHeight) / 2;
    }
    // The image_utils.dart processes the raw sensor image which is LANDSCAPE.
    // So it scales by width and adds padding to height (Y-padding).
    
    // We assume the sensor is landscape (aspect > 1.0)
    double sensorAspectRatio = cameraAspectRatio;
    if (sensorAspectRatio < 1.0) sensorAspectRatio = 1.0 / sensorAspectRatio;
    
    // In image_utils: 
    // scale = 640 / sensorWidth
    // newHeight = sensorHeight * scale = 640 / sensorAspectRatio
    double contentHeight = 640.0 / sensorAspectRatio;
    double lbOffsetY = (640.0 - contentHeight) / 2;

    for (var detection in detections) {
      // 4. Coordinate Transformation
      
      // Step A: Remove Y-Padding (Get coordinates in 640 x contentHeight space)
      double rawY = detection.y - lbOffsetY;
      double rawX = detection.x;
      
      // Step B: Normalize to 0..1 (Relative to Sensor Frame)
      double normX = rawX / 640.0;
      double normY = rawY / contentHeight;
      double normW = detection.width / 640.0;
      double normH = detection.height / contentHeight;
      
      // Step C: Rotate 90 Degrees (Sensor Landscape -> Screen Portrait)
      // Standard rotation: (x, y) -> (y, x) or (y, 1-x) depending on sensor mount.
      // Image evidence shows Left-Right Mirroring (Object Left, Bbox Right).
      // This requires X-axis inversion.
      
      // Screen X = (1.0 - normY) * previewWidth
      // Screen Y = normX * previewHeight
      
      double screenX = (1.0 - normY) * previewWidth;
      double screenY = normX * previewHeight;
      double screenW = normH * previewWidth;
      double screenH = normW * previewHeight;
      
      // Apply Screen Offsets
      // User feedback: "Height is a bit small... doesn't cover object fully"
      // Increased height multiplier to 1.25x to stretch vertically
      // Kept width multiplier at 1.1x
      double finalW = screenW * 1.1;
      double finalH = screenH * 1.25;
      
      double left = screenX + screenOffsetX - finalW / 2;
      double top = screenY + screenOffsetY - finalH / 2;

      final rect = Rect.fromLTWH(left, top, finalW, finalH);

      // Draw bounding box (Red)
      paint.color = Colors.red;
      canvas.drawRect(rect, paint);

      // Draw label
      final label = '${detection.className} ${(detection.confidence * 100).toStringAsFixed(0)}%';
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();

      final labelRect = Rect.fromLTWH(left, top - 20, textPainter.width + 8, 20);
      canvas.drawRect(labelRect, Paint()..color = Colors.red);
      textPainter.paint(canvas, Offset(left + 4, top - 18));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

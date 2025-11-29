import 'dart:io';
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
    // 3. Calculate Letterbox Info
    // Determine if sensor is Landscape or Portrait based on aspect ratio
    double sensorAspectRatio = cameraAspectRatio;
    
    double contentWidth = 640.0;
    double contentHeight = 640.0;
    double lbOffsetX = 0;
    double lbOffsetY = 0;
    
    if (sensorAspectRatio > 1.0) {
      // Landscape Sensor (e.g. Android) -> Y-Padding
      contentHeight = 640.0 / sensorAspectRatio;
      lbOffsetY = (640.0 - contentHeight) / 2;
    } else {
      // Portrait Sensor (e.g. iOS) -> X-Padding
      contentWidth = 640.0 * sensorAspectRatio;
      lbOffsetX = (640.0 - contentWidth) / 2;
    }

    for (var detection in detections) {
      // 4. Coordinate Transformation
      
      double screenX, screenY, screenW, screenH;
      
      if (Platform.isIOS) {
        // iOS: Stream is usually Portrait (matches screen) -> No Rotation needed
        // Remove X-Padding (if any)
        double rawX = detection.x - lbOffsetX;
        double rawY = detection.y - lbOffsetY;
        
        double normX = rawX / contentWidth;
        double normY = rawY / 640.0; // Height is full 640 in Portrait letterbox
        double normW = detection.width / contentWidth;
        double normH = detection.height / 640.0;
        
        // Direct Mapping (No Swap, No Mirroring)
        // User feedback indicates Mirroring logic moved box to wrong side.
        // Reverting to standard mapping.
        screenX = normX * previewWidth;
        screenY = normY * previewHeight;
        screenW = normW * previewWidth;
        screenH = normH * previewHeight;
        
      } else {
        // Android: Stream is Landscape (90 deg offset) -> Swap X/Y needed
        // Remove Y-Padding
        double rawY = detection.y - lbOffsetY;
        double rawX = detection.x;
        
        double normX = rawX / 640.0; // Width is full 640 in Landscape letterbox
        double normY = rawY / contentHeight;
        double normW = detection.width / 640.0;
        double normH = detection.height / contentHeight;
        
        // Rotate 90 deg + Invert X (Mirroring fix)
        screenX = (1.0 - normY) * previewWidth;
        screenY = normX * previewHeight;
        screenW = normH * previewWidth;
        screenH = normW * previewHeight;
      }
      
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

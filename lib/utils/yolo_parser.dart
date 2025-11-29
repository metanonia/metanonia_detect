import 'dart:math';
import '../models/detection.dart';

class YoloParser {
  // Class names for strawberry diseases
  static const List<String> classNames = [
    '열매_잿빛곰팡이병',
    '열매_흰가루병',
    '잎_흰가루병',
    '잎_역병',
    '잎_시들음병',
    '잎_잎끝마름',
    '잎_황화',
  ];

  static List<Detection> parseYoloOutput(
    List<double> output,
    double confidenceThreshold,
    double iouThreshold,
  ) {
    // Determine actual output shape from size
    // Expected: 92,400 = 1 * 11 * 8400 (not 1 * 84 * 8400)
    // Format: [batch, features, detections]
    // Features: [x, y, w, h, class0_conf, class1_conf, ..., class6_conf]
    
    final int numDetections = 8400;
    final int numClasses = classNames.length; // 7
    final int numFeatures = 4 + numClasses; // 11 = 4 bbox coords + 7 classes
    
    // Verify output size
    final expectedSize = 1 * numFeatures * numDetections;
    if (output.length != expectedSize) {
      print('WARNING: Output size mismatch. Got ${output.length}, expected $expectedSize');
      print('Calculated: 1 * $numFeatures * $numDetections = $expectedSize');
    }

    List<Detection> detections = [];

    // Helper function to get value at [feature_idx][detection_idx]
    // In flattened array [1, 11, 8400], index = feature_idx * 8400 + detection_idx
    double getValue(int featureIdx, int detectionIdx) {
      final index = featureIdx * numDetections + detectionIdx;
      if (index >= output.length) {
        print('ERROR: Index $index out of bounds (length: ${output.length})');
        return 0.0;
      }
      return output[index];
    }

    for (int i = 0; i < numDetections; i++) {
      // Get bounding box coordinates (first 4 features)
      // Standard YOLOv8/11 output is [cx, cy, w, h]
      final double cx = getValue(0, i);
      final double cy = getValue(1, i);
      final double w = getValue(2, i);
      final double h = getValue(3, i);
      
      // No conversion needed if output is already cx, cy, w, h

      // Find max class score (features 4 to 4+numClasses-1)
      double maxScore = 0;
      int maxClassId = 0;
      
      for (int c = 0; c < numClasses; c++) {
        final double score = getValue(4 + c, i);
        if (score > maxScore) {
          maxScore = score;
          maxClassId = c;
        }
      }

      // Filter by confidence
      if (maxScore > confidenceThreshold) {
        detections.add(Detection(
          x: cx,
          y: cy,
          width: w,
          height: h,
          confidence: maxScore,
          classId: maxClassId,
          className: classNames[maxClassId],
        ));
      }
    }

    // Debug logging only when detections found
    if (detections.isNotEmpty) {
      print('✓ ${detections.length} detections: ${detections.first.className} ${(detections.first.confidence * 100).toStringAsFixed(0)}%');
    }

    // Apply NMS
    return _nonMaxSuppression(detections, iouThreshold);
  }

  static List<Detection> _nonMaxSuppression(
    List<Detection> detections,
    double iouThreshold,
  ) {
    // Sort by confidence
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    List<Detection> result = [];
    List<bool> suppressed = List.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      
      result.add(detections[i]);

      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        
        final double iou = _calculateIoU(detections[i], detections[j]);
        if (iou > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    return result;
  }

  static double _calculateIoU(Detection a, Detection b) {
    final double x1 = max(a.x - a.width / 2, b.x - b.width / 2);
    final double y1 = max(a.y - a.height / 2, b.y - b.height / 2);
    final double x2 = min(a.x + a.width / 2, b.x + b.width / 2);
    final double y2 = min(a.y + a.height / 2, b.y + b.height / 2);

    final double intersectionArea = max(0, x2 - x1) * max(0, y2 - y1);
    final double unionArea = a.width * a.height + b.width * b.height - intersectionArea;

    return intersectionArea / unionArea;
  }
}

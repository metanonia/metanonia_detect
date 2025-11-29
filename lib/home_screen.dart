import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/camera_service.dart';
import 'services/inference_service.dart';
import 'utils/image_utils.dart';
import 'utils/yolo_parser.dart';
import 'models/detection.dart';
import 'widgets/bounding_box_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CameraService _cameraService = CameraService();
  final InferenceService _inferenceService = InferenceService();
  bool _isInitializing = true;
  String _resultText = "Initializing...";
  bool _isProcessing = false;
  int _lastRun = 0;
  List<Detection> _detections = [];
  bool _diseaseDetected = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _cameraService.initialize();
      await _inferenceService.initialize('assets/models/detect_model.onnx');
      setState(() {
        _isInitializing = false;
        _resultText = "Camera Ready. Model Loaded.";
      });
      
      _cameraService.startImageStream((image) async {
        if (_isProcessing) return;
        if (DateTime.now().millisecondsSinceEpoch - _lastRun < 1000) return; // 1 FPS limit for better performance

        _isProcessing = true;
        _lastRun = DateTime.now().millisecondsSinceEpoch;

        try {
          // Run heavy processing in Isolate
          final input = await ImageUtils.processCameraImage(image);
          
          final result = await _inferenceService.runInference(input);
            
          if (mounted && result != null && result.isNotEmpty) {
            // Parse YOLO output
            final detections = YoloParser.parseYoloOutput(
              result,
              0.5, // confidence threshold
              0.4, // IoU threshold for NMS
            );

            setState(() {
              _detections = detections;
              _diseaseDetected = detections.isNotEmpty;
              
              if (detections.isEmpty) {
                _resultText = "정상 - 질병 없음";
              } else {
                _resultText = "⚠️ 질병 발견: ${detections.length}개";
                
                // Vibrate and show alert
                HapticFeedback.vibrate();
                _showDiseaseAlert(detections);
              }
            });
          }
        } catch (e) {
          print("Error processing frame: $e");
        } finally {
          _isProcessing = false;
        }
      });
      
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _resultText = "Error: $e";
      });
    }
  }

  void _showDiseaseAlert(List<Detection> detections) {
    // Only show alert once per detection session
    if (_diseaseDetected) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ 질병 발견!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('다음 질병이 검출되었습니다:'),
            const SizedBox(height: 8),
            ...detections.map((d) => Text(
              '• ${d.className} (${(d.confidence * 100).toStringAsFixed(1)}%)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _inferenceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Strawberry Disease Detect"),
        backgroundColor: _diseaseDetected ? Colors.red : null,
      ),
      body: Stack(
        children: [
          if (_isInitializing)
            const Center(child: CircularProgressIndicator())
          else if (_cameraService.controller != null && _cameraService.controller!.value.isInitialized)
            Stack(
              children: [
                CameraPreview(_cameraService.controller!),
                
                // Bounding box overlay
                if (_detections.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BoundingBoxPainter(
                        detections: _detections,
                        imageSize: const Size(640, 640),
                        cameraController: _cameraService.controller!,
                      ),
                    ),
                  ),
              ],
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text("Camera Error", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_resultText, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
            
          // Red border when disease detected
          if (_diseaseDetected)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 8),
                  ),
                ),
              ),
            ),
            
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: _diseaseDetected ? Colors.red.withOpacity(0.9) : Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Text(
                _resultText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        ],
      ),
    );
  }
}

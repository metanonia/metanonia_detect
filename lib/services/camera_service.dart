import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  CameraController? get controller => _controller;

  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.low, // Reduce resolution to avoid OOM
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // YUV format for Android
      );
      await _controller!.initialize();
    }
  }

  Future<void> startImageStream(Function(CameraImage) onLatestImage) async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.startImageStream(onLatestImage);
    }
  }

  Future<void> stopImageStream() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }

  void dispose() {
    _controller?.dispose();
  }
}

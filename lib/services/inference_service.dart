import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

class InferenceService {
  OrtSession? _session;
  OrtEnv? _env;
  List<int>? _inputShape;

  Future<void> initialize(String assetPath) async {
    OrtEnv.instance.init();
    _env = OrtEnv.instance;
    
    final rawAssetFile = await rootBundle.load(assetPath);
    final bytes = rawAssetFile.buffer.asUint8List();
    
    final sessionOptions = OrtSessionOptions();
    
    _session = OrtSession.fromBuffer(bytes, sessionOptions);
    
    // Inspect input signature to determine shape
    // Note: This API might vary depending on the package version, 
    // but usually we can assume a fixed shape or try to read it.
    // For now, we'll default to 640x640 if we can't read it, or log it.
    print("Model loaded. Inputs: ${_session?.inputNames}");
    print("Model loaded. Outputs: ${_session?.outputNames}");
  }

  Future<List<double>?> runInference(List<double> inputData) async {
    if (_session == null) return null;

    final shape = [1, 3, 640, 640]; 
    final inputOrt = OrtValueTensor.createTensorWithDataList(inputData, shape);
    
    final runOptions = OrtRunOptions();
    final inputs = {'images': inputOrt};
    
    try {
      final outputs = _session!.run(runOptions, inputs);
      
      inputOrt.release();
      runOptions.release();

      if (outputs.isNotEmpty) {
        final outputValue = outputs[0];
        
        // YOLO output is typically [1, 11, 8400] for this model
        // We need to flatten it to a 1D list
        final dynamic rawOutput = outputValue?.value;
        List<double> flatOutput = [];
        
        if (rawOutput is List) {
          _flattenList(rawOutput, flatOutput);
        }
        
        outputValue?.release();
        return flatOutput;
      }
    } catch (e) {
      print("Inference error: $e");
    }
    
    return null;
  }

  void _flattenList(dynamic list, List<double> result) {
    if (list is List) {
      for (var item in list) {
        if (item is double) {
          result.add(item);
        } else if (item is int) {
          result.add(item.toDouble());
        } else if (item is List) {
          _flattenList(item, result);
        }
      }
    }
  }

  void dispose() {
    _session?.release();
  }
}

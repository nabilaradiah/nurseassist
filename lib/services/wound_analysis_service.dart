import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/wound_assessment.dart';
import '../models/wound_types_database.dart';
import 'ai_config.dart';
import 'skin_detection_service.dart';

/// Thrown by [WoundAnalysisService.analyzeWound] when the model's top-class
/// confidence falls below [AIConfig.noWoundConfidenceThreshold] and the guard
/// is enabled.  Callers should prompt the user to retake the photo rather than
/// displaying analysis results.
class NoWoundDetectedException implements Exception {
  final String message;
  const NoWoundDetectedException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the AI model can't analyse the photo (e.g. it failed to load
/// or run). The app then lets the nurse continue without an AI result and
/// set the wound type through the TIME assessment, instead of guessing.
class AiUnavailableException implements Exception {
  final String message;
  const AiUnavailableException(this.message);

  @override
  String toString() => message;
}

/// Wound Analysis Service
///
/// Analyses a wound photo with the on-device EfficientNetB0 model ('tflite').
/// There is deliberately no guessing fallback: if the model can't run, an
/// [AiUnavailableException] is thrown and the nurse's TIME assessment sets
/// the wound type instead.
///
/// Switch the active method in lib/services/ai_config.dart → analysisMethod.
class WoundAnalysisService {
  // ──────────────────────────────────────────────────────────────────────────
  // Internal state
  // ──────────────────────────────────────────────────────────────────────────

  Interpreter? _interpreter;
  bool _modelLoaded = false;

  // ──────────────────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────────────────

  /// Main entry point. Runs the skin gate, then the TFLite model.
  ///
  /// Throws [NoWoundDetectedException] when the photo doesn't look like a
  /// wound, and [AiUnavailableException] when the model can't produce a
  /// result — never a made-up classification.
  Future<WoundAnalysisResult> analyzeWound(File imageFile) async {
    try {
      // ── Skin detection gate (runs before the wound classifier) ───────────
      if (AIConfig.skinDetectionEnabled) {
        final hasSkin = await SkinDetectionService.containsSkin(imageFile);
        if (!hasSkin) {
          throw const NoWoundDetectedException(
            'No skin detected — please ensure the wound area is clearly visible.',
          );
        }
      }

      final method = AIConfig.analysisMethod;
      print('🔍 Starting wound analysis — method: $method');
      print('📊 Config: ${AIConfig.getConfigurationStatus()}');

      if (method != 'tflite') {
        throw AiUnavailableException(
          'AI analysis method "$method" is not available.',
        );
      }
      return await _analyzeWithTFLite(imageFile);
    } on NoWoundDetectedException {
      rethrow;
    } on AiUnavailableException {
      rethrow;
    } catch (e) {
      print('❌ Analysis error: $e');
      throw AiUnavailableException(
        'The AI model could not analyse this photo.',
      );
    }
  }

  /// Release interpreter resources.  Call when the owning widget is disposed.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TFLite on-device inference
  // ──────────────────────────────────────────────────────────────────────────

  /// Load the TFLite interpreter from assets (once; cached for subsequent
  /// calls).
  Future<void> _loadModel() async {
    if (_modelLoaded) return;

    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/${AIConfig.tfliteModelPath}',
        options: options,
      );
      _modelLoaded = true;
      print('✅ TFLite model loaded (${AIConfig.tfliteModelPath})');
    } catch (e) {
      print('❌ Failed to load TFLite model: $e');
      rethrow;
    }
  }

  /// Run inference with the on-device EfficientNetB0 model.
  ///
  /// The model expects:
  ///   Input  : [1, 224, 224, 3]  float32  — pixel values 0–255 (no /255
  ///             normalisation; EfficientNetB0's built-in preprocessing layer
  ///             handles that inside the model graph)
  ///   Output : [1, 8]            float32  — softmax probabilities for Type_1…8
  Future<WoundAnalysisResult> _analyzeWithTFLite(File imageFile) async {
    // ── Skin detection gate (MediaPipe) ──────────────────────────────────────
    // Runs before TFLite inference so non-skin images are rejected cheaply.
    if (AIConfig.skinDetectionEnabled) {
      print('🔬 Running skin detection gate…');
      final hasSkin = await SkinDetectionService.containsSkin(imageFile);
      if (!hasSkin) {
        print('🚫 Skin gate: no skin detected — rejecting image');
        throw NoWoundDetectedException(
          'No skin detected in the image. Please ensure the wound area '
          'is clearly visible and well-lit in the frame.',
        );
      }
      print('✅ Skin gate passed — proceeding to wound classification');
    }

    await _loadModel();

    final interpreter = _interpreter!;
    final h = AIConfig.tfliteInputHeight; // 224
    final w = AIConfig.tfliteInputWidth; // 224
    // channels = 3 (RGB) — tensor is built pixel-by-pixel as [r, g, b]
    final numClasses = AIConfig.tfliteNumClasses; // 8

    // ── 1. Preprocess image → [1, 224, 224, 3] float32 ───────────────────
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Cannot decode image');

    final resized = img.copyResize(decoded, width: w, height: h);

    // Build input tensor: shape [1, h, w, c]
    final input = List.generate(
      1,
      (_) => List.generate(
        h,
        (y) => List.generate(w, (x) {
          final pixel = resized.getPixel(x, y);
          // Return float values 0–255 (model normalises internally)
          return [pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble()];
        }),
      ),
    );

    // ── 2. Run inference ─────────────────────────────────────────────────
    // Output tensor: shape [1, numClasses]
    final output = List.generate(
      1,
      (_) => List<double>.filled(numClasses, 0.0),
    );

    interpreter.run(input, output);

    final probabilities = output[0];

    // ── 3. Argmax → wound type ───────────────────────────────────────────
    int maxIdx = 0;
    double maxProb = probabilities[0];
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIdx = i;
      }
    }

    // Model output index 0 → Type_1, index 7 → Type_8
    final typeId = maxIdx + 1;
    final typeName = WoundTypesDatabase.getWoundTypeName(typeId);
    final confidence = maxProb;

    print(
      '🎯 TFLite → $typeName  confidence: ${(confidence * 100).toStringAsFixed(1)}%',
    );

    // ── No-wound guard ────────────────────────────────────────────────────────
    // If the guard is enabled and the model isn't confident enough, the image
    // probably isn't a wound photo.  Toggle via AIConfig.noWoundDetectionEnabled.
    if (AIConfig.noWoundDetectionEnabled &&
        confidence < AIConfig.noWoundConfidenceThreshold) {
      print(
        '🚫 No-wound guard triggered — '
        '${(confidence * 100).toStringAsFixed(1)}% < '
        '${(AIConfig.noWoundConfidenceThreshold * 100).toStringAsFixed(0)}% threshold',
      );
      throw NoWoundDetectedException(
        'No wound detected — model confidence '
        '${(confidence * 100).toStringAsFixed(1)}% is below the '
        '${(AIConfig.noWoundConfidenceThreshold * 100).toStringAsFixed(0)}% threshold.',
      );
    }
    print('   Full probabilities: ${_formatProbabilities(probabilities)}');

    return _generateResultForWoundType(
      typeId,
      confidence,
      List<double>.from(probabilities),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Shared helpers
  // ──────────────────────────────────────────────────────────────────────────

  /// Build a [WoundAnalysisResult] from the wound types database.
  WoundAnalysisResult _generateResultForWoundType(
    int typeId,
    double confidence,
    List<double> allClassProbabilities,
  ) {
    final typeName = WoundTypesDatabase.getWoundTypeName(typeId);
    final woundData = WoundTypesDatabase.getWoundTypeData(typeName);
    final characteristics =
        woundData['characteristics'] as Map<String, dynamic>;

    return WoundAnalysisResult(
      confidenceScore: confidence,
      woundType: typeId,
      woundName: typeName,
      severity: woundData['severity'] as String,
      estimatedSize: null,
      allClassProbabilities: allClassProbabilities,
      characteristics: WoundCharacteristics(
        necroticTissue: characteristics['necroticTissue'] as String,
        infection: characteristics['infection'] as String,
        exudateLevel: characteristics['exudateLevel'] as String,
        tissueClassification: List<String>.from(
          characteristics['tissueClassification'],
        ),
      ),
      management: WoundTypesDatabase.getManagement(typeId),
      segmentationMapUrl: null,
    );
  }

  /// Human-readable probability vector for debug logging.
  String _formatProbabilities(List<double> probs) {
    return probs
        .asMap()
        .entries
        .map((e) => 'Type_${e.key + 1}: ${(e.value * 100).toStringAsFixed(1)}%')
        .join(', ');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Utility
  // ──────────────────────────────────────────────────────────────────────────

  /// Returns true for wound types that require a specialist to confirm the
  /// model prediction before the management plan is acted upon.
  bool requiresSpecialistConfirmation(int woundTypeId) =>
      WoundTypesDatabase.requiresSpecialistConfirmation(woundTypeId);
}

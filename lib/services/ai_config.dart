/// Configuration for AI/ML wound analysis services
library;

class AIConfig {
  // ========== ANALYSIS METHOD SELECTION ==========
  /// Active analysis method:
  /// - 'tflite': Use on-device TensorFlow Lite model (primary)

  static const String analysisMethod = 'tflite';

  // ========== TFLITE MODEL CONFIGURATION ==========

  /// TensorFlow Lite model path (relative to assets/)
  static const String tfliteModelPath = 'models/wound_classifier.tflite';

  /// Input shape for TFLite model
  static const int tfliteInputHeight = 224;
  static const int tfliteInputWidth = 224;

  /// Number of output classes (Type_1 through Type_8)
  static const int tfliteNumClasses = 8;

  // ========== SKIN DETECTION (MediaPipe pre-check) ==========

  /// When true, MediaPipe Selfie Segmentation runs before the wound classifier.
  /// Images with fewer than [skinDetectionMinRatio] skin pixels are rejected
  /// with a "No skin detected" message — no TFLite inference is wasted.
  /// Set to false to disable (e.g. while testing on non-photo inputs).
  static const bool skinDetectionEnabled = true;

  /// Minimum fraction of image pixels that must be classified as "skin/person"
  /// by MediaPipe for the image to pass the skin gate.
  /// 0.04 = 4 % — low enough to pass close-up wound shots (which may have
  /// little surrounding skin) while rejecting random objects/scenery.
  static const double skinDetectionMinRatio = 0.04;

  // ========== NO-WOUND DETECTION GUARD ==========

  /// Toggle the "no wound detected" guard on or off.
  /// true  → active: images where the model is not confident enough are
  ///         rejected and the user is asked to retake the photo.
  /// false → disabled: all images pass through regardless of confidence
  ///         (useful while testing the model on non-wound photos).
  static const bool noWoundDetectionEnabled = true;

  /// If [noWoundDetectionEnabled] is true, any TFLite prediction whose top
  /// class confidence is below this value is treated as "no wound detected".
  /// Start at 0.35 and adjust upward if real wound photos are being rejected,
  /// or downward if non-wound photos are still slipping through.
  static const double noWoundConfidenceThreshold = 0.35;

  // ========== STATUS ==========

  /// Get user-friendly configuration status message
  static String getConfigurationStatus() {
    switch (analysisMethod) {
      case 'tflite':
        return '📱 Using on-device TensorFlow Lite model';
      default:
        return '❌ Invalid analysis method selected';
    }
  }
}

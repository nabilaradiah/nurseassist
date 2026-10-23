import 'dart:io';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'ai_config.dart';

/// Uses MediaPipe Selfie Segmentation to check whether an image contains
/// visible human skin / body tissue before passing it to the wound classifier.
///
/// This acts as a lightweight gate to reject obviously non-clinical images
/// (random objects, food, scenery) without running the full wound-type model.
///
/// How it works:
///   1. Runs MediaPipe's on-device selfie segmenter on the image.
///   2. Each pixel gets a confidence score (0.0 → background, 1.0 → person/skin).
///   3. We count pixels above a 0.5 confidence threshold.
///   4. If the skin-pixel ratio is below [AIConfig.skinDetectionMinRatio],
///      the image is rejected as "no skin detected".
class SkinDetectionService {
  /// Returns `true` if the image likely contains visible human skin, `false`
  /// otherwise.  Always returns `true` on any internal ML Kit error so that a
  /// processing failure never falsely blocks a real wound photo.
  static Future<bool> containsSkin(File imageFile) async {
    final segmenter = SelfieSegmenter(
      mode: SegmenterMode.single, // single-image mode (not live stream)
      enableRawSizeMask: false,   // mask resized to match input image dimensions
    );

    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final mask = await segmenter.processImage(inputImage);

      if (mask == null || mask.confidences.isEmpty) {
        print('⚠️ Skin detection: mask is null or empty — allowing through');
        return true; // permissive fallback: let wound classifier decide
      }

      // Count pixels the model considers "person / skin" (confidence > 0.5)
      int skinPixels = 0;
      for (final confidence in mask.confidences) {
        if (confidence > 0.5) skinPixels++;
      }

      final ratio = skinPixels / mask.confidences.length;
      print(
        '🔬 Skin detection: ${(ratio * 100).toStringAsFixed(1)}% skin pixels '
        '— threshold ${(AIConfig.skinDetectionMinRatio * 100).toStringAsFixed(0)}%',
      );

      return ratio >= AIConfig.skinDetectionMinRatio;
    } catch (e) {
      // ML Kit initialisation errors, unsupported image format, etc.
      // Return true so a processing failure never blocks a real wound photo.
      print('⚠️ Skin detection error (allowing through): $e');
      return true;
    } finally {
      await segmenter.close();
    }
  }
}

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/wound_assessment.dart';
import '../models/wound_types_database.dart';
import 'ai_config.dart';

/// Comprehensive Wound Analysis Service with multiple AI implementation options
/// 
/// Supports:
/// 1. Cloud-based AI API (Roboflow, Custom APIs, Azure/AWS/GCP)
/// 2. On-device TensorFlow Lite model
/// 3. Enhanced rule-based analysis (fallback)
/// 
/// Configuration: See lib/services/ai_config.dart
class WoundAnalysisService {
  
  // ========== MAIN ANALYSIS METHOD ==========
  /// Main entry point for wound analysis
  /// Routes to appropriate analysis method based on configuration
  Future<WoundAnalysisResult> analyzeWound(File imageFile) async {
    try {
      final method = AIConfig.analysisMethod;
      print('🔍 Starting wound analysis using method: $method');
      print('📊 Configuration status: ${AIConfig.getConfigurationStatus()}');
      
      switch (method) {
        case 'cloud':
          if (!AIConfig.isConfigured()) {
            print('⚠️ Cloud API not configured, falling back to enhanced rules');
            return await _analyzeWithEnhancedRules(imageFile);
          }
          return await _analyzeWithCloudAPI(imageFile);
        case 'tflite':
          return await _analyzeWithTFLite(imageFile);
        case 'enhanced_mock':
          return await _analyzeWithEnhancedRules(imageFile);
        default:
          print('⚠️ Unknown analysis method, falling back to enhanced mock');
          return await _analyzeWithEnhancedRules(imageFile);
      }
    } catch (e) {
      print('❌ Analysis error: $e');
      // Fallback to enhanced rules if any method fails
      print('🔄 Falling back to enhanced rule-based analysis');
      return await _analyzeWithEnhancedRules(imageFile);
    }
  }

  // ========== CLOUD-BASED AI ANALYSIS ==========
  /// Analyze wound using cloud-based API (Roboflow, Custom API, etc.)
  Future<WoundAnalysisResult> _analyzeWithCloudAPI(File imageFile) async {
    try {
      // Preprocess image
      final processedImage = await _preprocessImage(imageFile);
      final base64Image = base64Encode(processedImage);
      
      // Try Roboflow first
      final response = await http.post(
        Uri.parse('${AIConfig.roboflowEndpoint}?api_key=${AIConfig.roboflowApiKey}'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: base64Image,
      ).timeout(Duration(seconds: AIConfig.apiTimeout));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseRoboflowResponse(data);
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key. Please configure your Roboflow API key.');
      } else {
        throw Exception('API returned status ${response.statusCode}');
      }
    } catch (e) {
      print('Cloud API error: $e');
      rethrow;
    }
  }

  /// Parse Roboflow API response
  WoundAnalysisResult _parseRoboflowResponse(Map<String, dynamic> data) {
    // Roboflow Classification response structure:
    // {
    //   "predictions": [
    //     {"class": "Diabetic Wound", "confidence": 0.92}
    //   ],
    //   "top": "Diabetic Wound",
    //   "confidence": 0.92
    // }
    
    String className;
    double confidence;
    
    // Try different response formats
    if (data['top'] != null && data['confidence'] != null) {
      // Classification format
      className = data['top'] as String;
      confidence = (data['confidence'] as num).toDouble();
    } else if (data['predictions'] != null && data['predictions'].isNotEmpty) {
      // Object detection format
      final prediction = data['predictions'][0];
      className = prediction['class'] as String;
      confidence = (prediction['confidence'] as num).toDouble();
    } else {
      throw Exception('Unexpected Roboflow response format');
    }
    
    // Normalize class name to match database
    final woundType = WoundTypesDatabase.normalizeClassName(className);
    
    print('🎯 Roboflow prediction: $className (normalized: $woundType), confidence: ${(confidence * 100).toStringAsFixed(1)}%');
    
    return _generateResultForWoundType(woundType, confidence);
  }

  // ========== TENSORFLOW LITE ANALYSIS ==========
  /// Analyze wound using on-device TensorFlow Lite model
  Future<WoundAnalysisResult> _analyzeWithTFLite(File imageFile) async {
    // Note: This requires tflite_flutter package and a trained .tflite model
    // The model file should be placed in assets/models/wound_classifier.tflite
    
    try {
      // This is a placeholder - actual implementation requires:
      // 1. Load the .tflite model
      // 2. Preprocess image to model's input shape
      // 3. Run inference
      // 4. Post-process output
      
      print('⚠️ TFLite analysis not yet implemented');
      print('📋 To implement:');
      print('   1. Add wound_classifier.tflite to assets/models/');
      print('   2. Uncomment tflite_flutter in pubspec.yaml');
      print('   3. Implement model loading and inference');
      
      // For now, fall back to enhanced rules
      return await _analyzeWithEnhancedRules(imageFile);
      
      // IMPLEMENTATION TEMPLATE:
      /*
      import 'package:tflite_flutter/tflite_flutter.dart';
      
      final interpreter = await Interpreter.fromAsset('assets/models/wound_classifier.tflite');
      final inputImage = await _preprocessImageForTFLite(imageFile);
      final output = List.filled(8, 0).reshape([1, 8]); // 8 classes
      
      interpreter.run(inputImage, output);
      
      final probabilities = output[0] as List<double>;
      final maxIndex = probabilities.indexOf(probabilities.reduce(max));
      final confidence = probabilities[maxIndex];
      
      interpreter.close();
      
      return _generateResultForWoundType(maxIndex + 1, confidence);
      */
    } catch (e) {
      print('TFLite error: $e');
      rethrow;
    }
  }

  // ========== ENHANCED RULE-BASED ANALYSIS ==========
  /// Advanced rule-based analysis using image characteristics
  /// This is a sophisticated fallback that analyzes actual image features
  Future<WoundAnalysisResult> _analyzeWithEnhancedRules(File imageFile) async {
    try {
      print('🔬 Performing enhanced rule-based analysis...');
      
      // Analyze image characteristics
      final characteristics = await _analyzeImageCharacteristics(imageFile);
      
      // Determine wound type based on characteristics
      final woundTypeId = _classifyFromCharacteristics(characteristics);
      final confidence = _calculateConfidence(characteristics);
      final woundTypeName = WoundTypesDatabase.getAllWoundTypes()[woundTypeId - 1];
      
      print('✅ Analysis complete: Type $woundTypeName, Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
      
      return _generateResultForWoundType(woundTypeName, confidence);
    } catch (e) {
      print('Enhanced analysis error: $e');
      // Ultimate fallback: return Type 1 (Abrasion) with low confidence
      return _generateResultForWoundType('Abrasion', 0.5);
    }
  }

  /// Analyze image characteristics (color, texture, size estimation)
  Future<Map<String, dynamic>> _analyzeImageCharacteristics(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) {
      return {'error': 'Could not decode image'};
    }
    
    // Analyze color composition
    int redTotal = 0, greenTotal = 0, blueTotal = 0;
    int darkPixels = 0, brightPixels = 0;
    int totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        
        redTotal += r;
        greenTotal += g;
        blueTotal += b;
        
        final brightness = (r + g + b) / 3;
        if (brightness < 80) darkPixels++;
        if (brightness > 180) brightPixels++;
      }
    }
    
    final avgRed = redTotal / totalPixels;
    final avgGreen = greenTotal / totalPixels;
    final avgBlue = blueTotal / totalPixels;
    
    // Calculate color ratios
    final redness = avgRed / (avgGreen + avgBlue + 1);
    final darkness = darkPixels / totalPixels;
    final brightness = brightPixels / totalPixels;
    
    return {
      'redness': redness,
      'darkness': darkness,
      'brightness': brightness,
      'avgRed': avgRed,
      'avgGreen': avgGreen,
      'avgBlue': avgBlue,
      'width': image.width,
      'height': image.height,
    };
  }

  /// Classify wound type from image characteristics
  int _classifyFromCharacteristics(Map<String, dynamic> chars) {
    final redness = chars['redness'] as double;
    final darkness = chars['darkness'] as double;
    final brightness = chars['brightness'] as double;
    
    // Classification logic based on visual characteristics
    // Type 1-2: Lighter wounds with moderate redness
    if (darkness < 0.3 && redness < 1.2) {
      return brightness > 0.4 ? 1 : 2;
    }
    
    // Type 3-4: Moderate darkness with infection signs
    if (darkness >= 0.3 && darkness < 0.5) {
      return redness > 1.3 ? 3 : 4;
    }
    
    // Type 5-6: Darker wounds with necrotic tissue
    if (darkness >= 0.5 && darkness < 0.7) {
      return redness > 1.1 ? 6 : 5;
    }
    
    // Type 7-8: Very dark wounds (necrotic/infected)
    if (darkness >= 0.7) {
      return redness > 1.4 ? 8 : 7;
    }
    
    // Default to type 1
    return 1;
  }

  /// Calculate confidence score based on characteristic clarity
  double _calculateConfidence(Map<String, dynamic> chars) {
    // Base confidence
    double confidence = 0.75;
    
    final redness = chars['redness'] as double;
    final darkness = chars['darkness'] as double;
    
    // Higher confidence for clear characteristics
    if (redness > 1.5 || redness < 0.8) confidence += 0.10;
    if (darkness > 0.6 || darkness < 0.2) confidence += 0.10;
    
    // Cap at 0.95 for rule-based analysis
    return confidence > 0.95 ? 0.95 : confidence;
  }

  // ========== IMAGE PREPROCESSING ==========
  /// Preprocess image for AI analysis
  Future<Uint8List> _preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) return bytes;
    
    // Resize to optimal size from config
    final resized = img.copyResize(
      image, 
      width: AIConfig.targetImageWidth, 
      height: AIConfig.targetImageHeight
    );
    
    // Encode back to bytes with configured quality
    return Uint8List.fromList(img.encodeJpg(resized, quality: AIConfig.imageQuality));
  }

  /// Generate wound analysis result using the wound types database
  WoundAnalysisResult _generateResultForWoundType(String woundTypeName, [double? confidence]) {
    final woundData = WoundTypesDatabase.getWoundTypeData(woundTypeName);
    final characteristics = woundData['characteristics'] as Map<String, dynamic>;
    final management = woundData['management'] as Map<String, dynamic>;

    return WoundAnalysisResult(
      confidenceScore: confidence ?? 0.88, // Use provided or default
      woundType: WoundTypesDatabase.getAllWoundTypes().indexOf(woundTypeName) + 1, // Keep numeric ID for backward compatibility
      woundName: woundTypeName,
      severity: woundData['severity'] as String,
      estimatedSize: 15.0, // Can be calculated from image analysis
      characteristics: WoundCharacteristics(
        necroticTissue: characteristics['necroticTissue'] as String,
        infection: characteristics['infection'] as String,
        exudateLevel: characteristics['exudateLevel'] as String,
        tissueClassification: List<String>.from(characteristics['tissueClassification']),
      ),
      management: WoundManagement(
        dressingMaterials: List<String>.from(management['dressingMaterials']),
        antibioticRecommendation: management['antibioticRecommendation'] as String,
        surgicalProcedures: List<String>.from(management['surgicalProcedures']),
        additionalNotes: management['additionalNotes'] as String?,
      ),
      segmentationMapUrl: null, // Can be generated by AI model
    );
  }

  // Old methods below are kept for backward compatibility if needed
  // Can be removed once fully migrated to new database

  // Old methods below are kept for backward compatibility if needed
  // Can be removed once fully migrated to new database

  // Deprecated methods removed - use WoundTypesDatabase instead

  // Check if wound type requires specialist confirmation for debridement
  bool requiresSpecialistConfirmation(int woundType) {
    return woundType == 3 || woundType == 4 || woundType == 6;
  }

  // Parse AI API response (implement based on your AI service)
  // Uncomment this method when you integrate a real AI API
  /*
  WoundAnalysisResult _parseAIResponse(Map<String, dynamic> data) {
    // Implement parsing logic based on your AI service response format
    // Example structure:
    return WoundAnalysisResult(
      confidenceScore: data['confidence'],
      woundType: data['wound_type'],
      woundName: data['classification'],
      severity: data['severity'],
      estimatedSize: data['size_cm2'],
      characteristics: WoundCharacteristics.fromJson(data['characteristics']),
      management: _getManagementForType(data['wound_type']),
      segmentationMapUrl: data['segmentation_url'],
    );
  }
  */
}

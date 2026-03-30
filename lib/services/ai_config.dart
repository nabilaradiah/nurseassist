/// Configuration for AI/ML wound analysis services
/// 
/// IMPORTANT: API keys are loaded from .env file, not hardcoded!
/// See .env.example for the required environment variables.
/// 
/// TO USE ROBOFLOW:
/// 1. Set analysisMethod = 'cloud'
/// 2. Copy .env.example to .env and add your Roboflow credentials
/// 3. The app will load keys from .env automatically
library;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIConfig {
  // ========== ANALYSIS METHOD SELECTION ==========
  /// Choose your analysis method:
  /// - 'cloud': Use cloud-based AI API (requires API key)
  /// - 'tflite': Use on-device TensorFlow Lite model (requires .tflite file)
  /// - 'enhanced_mock': Use enhanced rule-based analysis (works offline, no setup)

  static const String analysisMethod = 'cloud';
  
  // ========== CLOUD API CONFIGURATIONS ==========
  
  /// Roboflow Configuration - loaded from .env file
  /// Sign up at: https://roboflow.com
  /// Get API key from: https://app.roboflow.com/settings/api
  static String get roboflowApiKey => 
    dotenv.env['ROBOFLOW_API_KEY'] ?? 'YOUR_ROBOFLOW_API_KEY_HERE';
  
  static String get roboflowWorkspace => 
    dotenv.env['ROBOFLOW_WORKSPACE'] ?? 'wound-classification-yigvv';
  
  static String get roboflowProject => 
    dotenv.env['ROBOFLOW_PROJECT'] ?? 'wound-classification-nfw1l';
  
  static String get roboflowVersion => 
    dotenv.env['ROBOFLOW_VERSION'] ?? '1';
  
  /// Endpoint for classification models (use 'detect' for object detection)
  static String get roboflowEndpoint => 
    'https://classify.roboflow.com/$roboflowProject/$roboflowVersion';
  
  /// Custom API Configuration
  /// Use this if you have your own trained model deployed
  static const String customApiEndpoint = 'https://your-api.com/analyze';
  static String get customApiKey => 
    dotenv.env['CUSTOM_API_KEY'] ?? 'YOUR_CUSTOM_API_KEY_HERE';
  
  /// Google Cloud Vision Configuration
  /// Get API key from: https://console.cloud.google.com
  static String get googleCloudApiKey => 
    dotenv.env['GOOGLE_CLOUD_API_KEY'] ?? 'YOUR_GOOGLE_CLOUD_API_KEY_HERE';
  static const String googleCloudProjectId = 'your-project-id';
  
  // ========== TFLITE MODEL CONFIGURATION ==========
  
  /// TensorFlow Lite model path (relative to assets/)
  static const String tfliteModelPath = 'models/wound_classifier.tflite';
  
  /// Model labels file path
  static const String tfliteLabelsPath = 'models/wound_labels.txt';
  
  /// Input shape for TFLite model
  static const int tfliteInputHeight = 224;
  static const int tfliteInputWidth = 224;
  static const int tfliteInputChannels = 3;
  
  /// Number of output classes (10 wound types + normal)
  static const int tfliteNumClasses = 10;
  
  // ========== ANALYSIS PARAMETERS ==========
  
  /// Minimum confidence threshold for accepting AI predictions
  static const double minConfidenceThreshold = 0.60;
  
  /// Timeout for API requests (in seconds)
  static const int apiTimeout = 30;
  
  /// Maximum image size for upload (in MB)
  static const int maxImageSizeMB = 5;
  
  /// Target image resolution for AI analysis
  static const int targetImageWidth = 640;
  static const int targetImageHeight = 640;
  
  /// JPEG quality for compressed images
  static const int imageQuality = 85;
  
  // ========== VALIDATION ==========
  
  /// Check if configuration is valid for the selected method
  static bool isConfigured() {
    switch (analysisMethod) {
      case 'cloud':
        return _isCloudConfigured();
      case 'tflite':
        return true; // Model existence checked at runtime
      case 'enhanced_mock':
        return true; // No configuration needed
      default:
        return false;
    }
  }
  
  static bool _isCloudConfigured() {
    // Check if at least one cloud service is configured
    if (roboflowApiKey != 'YOUR_ROBOFLOW_API_KEY_HERE' && 
        roboflowApiKey.isNotEmpty) {
      return true;
    }
    if (customApiKey != 'YOUR_CUSTOM_API_KEY_HERE' && 
        customApiKey.isNotEmpty) {
      return true;
    }
    if (googleCloudApiKey != 'YOUR_GOOGLE_CLOUD_API_KEY_HERE' && 
        googleCloudApiKey.isNotEmpty) {
      return true;
    }
    return false;
  }
  
  /// Get user-friendly configuration status message
  static String getConfigurationStatus() {
    switch (analysisMethod) {
      case 'cloud':
        if (isConfigured()) {
          return '✅ Cloud API configured and ready';
        } else {
          return '⚠️ Cloud API selected but no API key configured';
        }
      case 'tflite':
        return '📱 Using on-device TensorFlow Lite model';
      case 'enhanced_mock':
        return '🔧 Using enhanced rule-based analysis (works offline)';
      default:
        return '❌ Invalid analysis method selected';
    }
  }
}

/// Environment-specific configuration
/// Override these in production using environment variables
class EnvironmentConfig {
  static const bool isProduction = false;
  static const bool enableLogging = true;
  static const bool enableAnalytics = false;
}

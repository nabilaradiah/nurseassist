import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();

  factory LocalStorageService() {
    return _instance;
  }

  LocalStorageService._internal();

  /// Get the app documents directory where images will be stored
  Future<Directory> get _appDocDir async {
    return await getApplicationDocumentsDirectory();
  }

  /// Get the wound images directory
  Future<Directory> get woundImagesDir async {
    final appDocDir = await _appDocDir;
    final woundDir = Directory('${appDocDir.path}/wound_images');
    
    // Create directory if it doesn't exist
    if (!await woundDir.exists()) {
      await woundDir.create(recursive: true);
    }
    
    return woundDir;
  }

  /// Save image file to local storage
  /// Returns the local file path
  Future<String> saveWoundImage(File imageFile, String fileName) async {
    try {
      final dir = await woundImagesDir;
      final newFile = File('${dir.path}/$fileName');
      
      // Copy image to app documents directory
      await imageFile.copy(newFile.path);
      
      return newFile.path;
    } catch (e) {
      print('Error saving image: $e');
      rethrow;
    }
  }

  /// Get image file from local storage
  Future<File?> getWoundImage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      print('Error retrieving image: $e');
      return null;
    }
  }

  /// Delete image file from local storage
  Future<void> deleteWoundImage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting image: $e');
    }
  }

  /// Check if file path is local storage (not HTTP URL)
  static bool isLocalPath(String filePath) {
    return !filePath.startsWith('http');
  }

  /// Get total size of all wound images stored locally
  Future<int> getTotalImagesSize() async {
    try {
      final dir = await woundImagesDir;
      int totalSize = 0;

      if (await dir.exists()) {
        final files = dir.listSync(recursive: true);
        for (var file in files) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }

      return totalSize;
    } catch (e) {
      print('Error calculating images size: $e');
      return 0;
    }
  }

  /// Clear all wound images
  Future<void> clearAllImages() async {
    try {
      final dir = await woundImagesDir;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        // Recreate empty directory
        await dir.create(recursive: true);
      }
    } catch (e) {
      print('Error clearing images: $e');
    }
  }

  /// Get list of all stored wound image paths
  Future<List<String>> getAllImagePaths() async {
    try {
      final dir = await woundImagesDir;
      final List<String> imagePaths = [];

      if (await dir.exists()) {
        final files = dir.listSync(recursive: false);
        for (var file in files) {
          if (file is File) {
            imagePaths.add(file.path);
          }
        }
      }

      return imagePaths;
    } catch (e) {
      print('Error getting image paths: $e');
      return [];
    }
  }
}

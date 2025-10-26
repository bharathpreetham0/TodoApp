import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';

/// Supported AI model sizes
enum ModelSize {
  small('SmolLM-135M-Q4', 'SmolLM-135M-Instruct-Q4_K_M.gguf', 80),
  medium('SmolLM-360M-Q4', 'SmolLM-360M-Instruct-Q4_K_M.gguf', 220),
  large('Qwen2-0.5B-Q4', 'Qwen2-0.5B-Instruct-Q4_K_M.gguf', 350);

  const ModelSize(this.displayName, this.fileName, this.sizeMB);

  final String displayName;
  final String fileName;
  final int sizeMB;

  String get huggingFaceUrl {
    switch (this) {
      case ModelSize.small:
        return 'https://huggingface.co/HuggingFaceTB/SmolLM-135M-Instruct-GGUF/resolve/main/$fileName';
      case ModelSize.medium:
        return 'https://huggingface.co/HuggingFaceTB/SmolLM-360M-Instruct-GGUF/resolve/main/$fileName';
      case ModelSize.large:
        return 'https://huggingface.co/Qwen/Qwen2-0.5B-Instruct-GGUF/resolve/main/$fileName';
    }
  }
}

/// Download progress callback
typedef DownloadProgressCallback = void Function(double progress, int downloaded, int total);

/// Model download status
enum DownloadStatus {
  notStarted,
  downloading,
  completed,
  failed,
  cancelled,
}

/// Model downloader service
class ModelDownloader {
  final Logger _logger;
  http.Client? _httpClient;
  bool _isCancelled = false;

  ModelDownloader({Logger? logger}) : _logger = logger ?? Logger();

  /// Get the directory where models are stored
  Future<Directory> getModelsDirectory() async {
    if (kIsWeb) {
      // Web doesn't have a file system - models are loaded from CDN or IndexedDB
      throw UnsupportedError('File system not available on web');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(appDir.path, 'models'));

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    return modelsDir;
  }

  /// Get the full path for a model file
  Future<String> getModelPath(ModelSize size) async {
    final modelsDir = await getModelsDirectory();
    return p.join(modelsDir.path, size.fileName);
  }

  /// Check if a model is downloaded
  Future<bool> isModelDownloaded(ModelSize size) async {
    if (kIsWeb) {
      // For web, check localStorage or IndexedDB
      // This is a placeholder - actual implementation would check browser storage
      return false;
    }

    try {
      final path = await getModelPath(size);
      final file = File(path);
      final exists = await file.exists();

      if (exists) {
        final stat = await file.stat();
        final expectedSize = size.sizeMB * 1024 * 1024;
        // Allow 5% variance in file size
        final isValidSize = (stat.size - expectedSize).abs() < (expectedSize * 0.05);

        if (!isValidSize) {
          _logger.w('Model file size mismatch. Expected ~${size.sizeMB}MB, got ${stat.size / 1024 / 1024}MB');
        }

        return isValidSize;
      }

      return false;
    } catch (e) {
      _logger.e('Error checking model download status: $e');
      return false;
    }
  }

  /// Download a model with progress tracking
  Future<DownloadStatus> downloadModel({
    required ModelSize size,
    DownloadProgressCallback? onProgress,
  }) async {
    if (kIsWeb) {
      _logger.w('Model download not supported on web - using WebLLM instead');
      return DownloadStatus.failed;
    }

    _isCancelled = false;
    _httpClient = http.Client();

    try {
      _logger.i('Starting download of ${size.displayName} model...');

      final modelPath = await getModelPath(size);
      final modelFile = File(modelPath);

      // Check if already downloaded
      if (await isModelDownloaded(size)) {
        _logger.i('Model already downloaded');
        return DownloadStatus.completed;
      }

      // Delete partial download if exists
      if (await modelFile.exists()) {
        await modelFile.delete();
      }

      // Start download
      final url = Uri.parse(size.huggingFaceUrl);
      final request = http.Request('GET', url);
      final response = await _httpClient!.send(request);

      if (response.statusCode != 200) {
        _logger.e('Download failed with status: ${response.statusCode}');
        return DownloadStatus.failed;
      }

      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;

      // Download with progress tracking
      final sink = modelFile.openWrite();

      await for (final chunk in response.stream) {
        if (_isCancelled) {
          await sink.close();
          if (await modelFile.exists()) {
            await modelFile.delete();
          }
          _logger.i('Download cancelled');
          return DownloadStatus.cancelled;
        }

        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (onProgress != null && totalBytes > 0) {
          final progress = downloadedBytes / totalBytes;
          onProgress(progress, downloadedBytes, totalBytes);
        }
      }

      await sink.close();

      // Verify download
      if (await isModelDownloaded(size)) {
        _logger.i('Model downloaded successfully: ${size.displayName}');
        return DownloadStatus.completed;
      } else {
        _logger.e('Download completed but file verification failed');
        return DownloadStatus.failed;
      }
    } catch (e) {
      _logger.e('Error downloading model: $e');
      return DownloadStatus.failed;
    } finally {
      _httpClient?.close();
      _httpClient = null;
    }
  }

  /// Cancel ongoing download
  void cancelDownload() {
    _isCancelled = true;
    _httpClient?.close();
    _httpClient = null;
  }

  /// Delete a downloaded model
  Future<bool> deleteModel(ModelSize size) async {
    if (kIsWeb) {
      _logger.w('Model deletion not supported on web');
      return false;
    }

    try {
      final path = await getModelPath(size);
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
        _logger.i('Deleted model: ${size.displayName}');
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Error deleting model: $e');
      return false;
    }
  }

  /// Get total size of all downloaded models
  Future<int> getTotalModelsSize() async {
    if (kIsWeb) return 0;

    int totalSize = 0;

    for (final size in ModelSize.values) {
      if (await isModelDownloaded(size)) {
        final path = await getModelPath(size);
        final file = File(path);
        final stat = await file.stat();
        totalSize += stat.size;
      }
    }

    return totalSize;
  }

  /// Get list of downloaded models
  Future<List<ModelSize>> getDownloadedModels() async {
    if (kIsWeb) return [];

    final downloaded = <ModelSize>[];

    for (final size in ModelSize.values) {
      if (await isModelDownloaded(size)) {
        downloaded.add(size);
      }
    }

    return downloaded;
  }

  /// Format bytes to human-readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

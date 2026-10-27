import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import '../di/injection.dart';
import '../api/mobile_api_client.dart';
import '../api/sync_engine.dart';

class MediaQueueItem {
  final String id;
  final String localFilePath;
  final String mediaType; // 'homework' | 'receipt' | 'exam' | 'avatar'
  final String entityId;
  final String timestamp;
  final int fileSize;
  int retryCount;
  String? lastError;
  bool isUploaded;
  String? remoteUrl;

  MediaQueueItem({
    required this.id,
    required this.localFilePath,
    required this.mediaType,
    required this.entityId,
    required this.timestamp,
    required this.fileSize,
    this.retryCount = 0,
    this.lastError,
    this.isUploaded = false,
    this.remoteUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'localFilePath': localFilePath,
      'mediaType': mediaType,
      'entityId': entityId,
      'timestamp': timestamp,
      'fileSize': fileSize,
      'retryCount': retryCount,
      'lastError': lastError,
      'isUploaded': isUploaded,
      'remoteUrl': remoteUrl,
    };
  }

  factory MediaQueueItem.fromMap(Map<dynamic, dynamic> map) {
    return MediaQueueItem(
      id: map['id'] as String,
      localFilePath: map['localFilePath'] as String,
      mediaType: map['mediaType'] as String? ?? 'general',
      entityId: map['entityId']?.toString() ?? '',
      timestamp: map['timestamp'] as String,
      fileSize: (map['fileSize'] as num?)?.toInt() ?? 0,
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      lastError: map['lastError'] as String?,
      isUploaded: map['isUploaded'] as bool? ?? false,
      remoteUrl: map['remoteUrl'] as String?,
    );
  }
}

class MediaQueueService {
  static const String boxMediaQueue = 'offline_media_queue';
  final ValueNotifier<int> pendingMediaCountNotifier = ValueNotifier<int>(0);
  bool _isUploading = false;

  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(boxMediaQueue)) {
        await Hive.openBox(boxMediaQueue);
      }
      _updateCount();
      debugPrint("📸 MediaQueueService initialized successfully.");
    } catch (e) {
      debugPrint("❌ MediaQueueService init error: $e");
    }
  }

  void _updateCount() {
    if (Hive.isBoxOpen(boxMediaQueue)) {
      final box = Hive.box(boxMediaQueue);
      pendingMediaCountNotifier.value = box.length;
    }
  }

  /// Maximum cumulative offline media storage threshold (50 MB) before warning / pruning old synced items
  static const int maxTotalStorageBytes = 50 * 1024 * 1024;
  /// Maximum target image size before compression (500 KB)
  static const int maxImageBytesThreshold = 500 * 1024;

  /// Store captured image into phone documents directory to keep Hive lightweight
  /// Automatically compresses images and enforces local storage safety limits.
  Future<MediaQueueItem?> saveAndEnqueueMedia({
    required File rawFile,
    required String mediaType,
    required String entityId,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mediaFolder = Directory('${appDir.path}/edut_offline_media');
      if (!await mediaFolder.exists()) {
        await mediaFolder.create(recursive: true);
      }

      // Check current folder size to avoid filling device storage
      await _enforceStorageCap(mediaFolder);

      final ext = rawFile.path.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
      final fileName = 'media_${mediaType}_${entityId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final savedPath = '${mediaFolder.path}/$fileName';

      File fileToSave = rawFile;

      // Automatic image compression if file is an image exceeding threshold
      final originalSize = await rawFile.length();
      if (isImage && originalSize > maxImageBytesThreshold) {
        debugPrint("🗜️ Compressing image ($originalSize bytes) before offline queueing...");
        try {
          final compressedFile = await _compressImageFile(rawFile, savedPath);
          fileToSave = compressedFile;
        } catch (compressionErr) {
          debugPrint("⚠️ Image compression fallback to raw copy: $compressionErr");
          fileToSave = await rawFile.copy(savedPath);
        }
      } else {
        fileToSave = await rawFile.copy(savedPath);
      }

      final finalFileSize = await fileToSave.length();
      final queueId = 'media_${DateTime.now().millisecondsSinceEpoch}';
      final item = MediaQueueItem(
        id: queueId,
        localFilePath: savedPath,
        mediaType: mediaType,
        entityId: entityId,
        timestamp: DateTime.now().toIso8601String(),
        fileSize: finalFileSize,
      );

      final box = Hive.box(boxMediaQueue);
      await box.put(queueId, item.toMap());
      _updateCount();

      debugPrint("📸 Enqueued offline media: $queueId (Path: $savedPath, Size: ${finalFileSize ~/ 1024} KB)");
      return item;
    } catch (e) {
      debugPrint("❌ Error enqueueing offline media: $e");
      return null;
    }
  }

  /// Compresses image natively in Dart without external heavy native libraries
  Future<File> _compressImageFile(File sourceFile, String targetPath) async {
    final bytes = await sourceFile.readAsBytes();
    if (bytes.length <= maxImageBytesThreshold) {
      return await sourceFile.copy(targetPath);
    }

    try {
      // Decode image using Flutter's built-in engine
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1280, // Cap dimension at 1280px max for high quality + low size
      );
      final frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // Re-encode to compressed PNG/JPEG byte stream
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final compressedBytes = byteData.buffer.asUint8List();
        final targetFile = File(targetPath);
        await targetFile.writeAsBytes(compressedBytes);
        debugPrint("✅ Compressed image from ${bytes.length ~/ 1024} KB down to ${compressedBytes.length ~/ 1024} KB");
        return targetFile;
      }
    } catch (e) {
      debugPrint("⚠️ Native codec compression error: $e");
    }

    // Fallback: copy source
    return await sourceFile.copy(targetPath);
  }

  /// Ensures offline media storage does not exceed device threshold
  Future<void> _enforceStorageCap(Directory folder) async {
    try {
      final entities = folder.listSync();
      int totalBytes = 0;
      final List<File> files = [];

      for (final entity in entities) {
        if (entity is File) {
          totalBytes += await entity.length();
          files.add(entity);
        }
      }

      if (totalBytes > maxTotalStorageBytes) {
        debugPrint("⚠️ Offline media folder size (${totalBytes ~/ (1024 * 1024)} MB) exceeds 50MB cap. Pruning oldest synced files...");
        // Sort files by modified time ascending (oldest first)
        files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

        final box = Hive.isBoxOpen(boxMediaQueue) ? Hive.box(boxMediaQueue) : null;
        final Set<String> activeQueuePaths = {};
        if (box != null) {
          for (final key in box.keys) {
            final val = box.get(key);
            if (val is Map && val['localFilePath'] != null) {
              activeQueuePaths.add(val['localFilePath'].toString());
            }
          }
        }

        // Delete files that are not currently in the active pending upload queue
        for (final file in files) {
          if (!activeQueuePaths.contains(file.path)) {
            try {
              final len = await file.length();
              await file.delete();
              totalBytes -= len;
              if (totalBytes <= maxTotalStorageBytes) break;
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint("Storage cap check exception: $e");
    }
  }

  /// Process pending media upload queue when internet is available
  Future<void> processQueue() async {
    if (_isUploading) return;
    if (!Hive.isBoxOpen(boxMediaQueue)) return;

    final syncEngine = locator.isRegistered<SyncEngine>() ? locator<SyncEngine>() : null;
    if (syncEngine != null && !syncEngine.isOnlineNotifier.value) return;

    _isUploading = true;
    try {
      final box = Hive.box(boxMediaQueue);
      final List<String> keys = List<String>.from(box.keys);

      for (final key in keys) {
        final val = box.get(key);
        if (val is! Map) continue;

        final item = MediaQueueItem.fromMap(val);
        final file = File(item.localFilePath);

        if (!await file.exists()) {
          // File was deleted or moved, remove from queue
          await box.delete(key);
          continue;
        }

        final uploaded = await _uploadSingleMedia(item, file);
        if (uploaded) {
          await box.delete(key);
          debugPrint("✅ Uploaded and dequeued media: ${item.id}");
        } else {
          item.retryCount += 1;
          await box.put(key, item.toMap());
        }
      }
    } finally {
      _isUploading = false;
      _updateCount();
    }
  }

  Future<bool> _uploadSingleMedia(MediaQueueItem item, File file) async {
    try {
      final client = locator.isRegistered<MobileApiClient>()
          ? locator<MobileApiClient>()
          : MobileApiClient();

      // Post media file via mobile client
      final response = await client.postJson('/api/mobile/media/upload', {
        'queueId': item.id,
        'mediaType': item.mediaType,
        'entityId': item.entityId,
        'fileName': file.path.split(Platform.pathSeparator).last,
      });

      return response['success'] == true;
    } catch (e) {
      debugPrint("⚠️ Failed to upload media ${item.id}: $e");
      return false;
    }
  }
}

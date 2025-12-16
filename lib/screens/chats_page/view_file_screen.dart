import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ixes.app/screens/chats_page/pdf_viewerscreen.dart';
import 'package:ixes.app/screens/chats_page/video_player_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import 'image_viewerscreen.dart';

class FileViewerHelper {
  /// Determine file type from URL or filename
  static String getFileType(String fileUrl) {
    final extension = fileUrl.split('.').last.toLowerCase().split('?').first;

    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      return 'image';
    } else if (extension == 'pdf') {
      return 'pdf';
    } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
      return 'video';
    } else if (['mp3', 'wav', 'aac', 'm4a', 'ogg'].contains(extension)) {
      return 'audio';
    }

    // Try to detect from URL path if no extension
    if (fileUrl.contains('/images/') || fileUrl.contains('/image/')) {
      return 'image';
    } else if (fileUrl.contains('/videos/') || fileUrl.contains('/video/')) {
      return 'video';
    } else if (fileUrl.contains('/pdfs/') || fileUrl.contains('/pdf/')) {
      return 'pdf';
    }

    return 'other';
  }

  /// Open file with appropriate viewer
  static Future<void> openFile({
    required BuildContext context,
    required String fileUrl,
    required String fileName,
    String? localFilePath,
  }) async {
    try {
      print('📂 Opening file: $fileName');
      print('🔗 File URL: $fileUrl');
      print('📍 Local path: $localFilePath');

      final fileType = getFileType(fileUrl);
      print('📋 Detected file type: $fileType');

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      switch (fileType) {
        case 'image':
          Navigator.pop(context); // Close loading
          _openImageViewer(context, fileUrl, fileName);
          break;

        case 'pdf':
          final localPath = await _ensureLocalFile(fileUrl, fileName, localFilePath);
          Navigator.pop(context); // Close loading
          if (localPath != null) {
            _openPdfViewer(context, localPath, fileName);
          } else {
            _showError(context, 'Failed to load PDF file');
          }
          break;

        case 'video':
          final localPath = await _ensureLocalFile(fileUrl, fileName, localFilePath);
          Navigator.pop(context); // Close loading
          if (localPath != null) {
            _openVideoPlayer(context, localPath, fileName);
          } else {
            _showError(context, 'Failed to load video file');
          }
          break;

        default:
        // For other files, download and open with system app
          final localPath = await _ensureLocalFile(fileUrl, fileName, localFilePath);
          Navigator.pop(context); // Close loading

          if (localPath != null) {
            final result = await OpenFile.open(localPath);
            if (result.type != ResultType.done) {
              _showError(context, 'Cannot open this file type');
            }
          } else {
            _showError(context, 'Failed to load file');
          }
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      print('💥 Error opening file: $e');
      _showError(context, 'Error opening file: $e');
    }
  }

  /// Ensure file is available locally
  static Future<String?> _ensureLocalFile(
      String fileUrl,
      String fileName,
      String? localFilePath,
      ) async {
    try {
      print('📥 Ensuring local file...');

      // Check if local file exists
      if (localFilePath != null && localFilePath.isNotEmpty) {
        final localFile = File(localFilePath);
        if (await localFile.exists()) {
          print('✅ Using existing local file: $localFilePath');
          return localFilePath;
        }
      }

      // Check if already cached
      final tempDir = await getTemporaryDirectory();
      final cachedPath = '${tempDir.path}/$fileName';
      final cachedFile = File(cachedPath);

      if (await cachedFile.exists()) {
        final size = await cachedFile.length();
        if (size > 0) {
          print('✅ Using cached file: $cachedPath');
          return cachedPath;
        } else {
          print('⚠️ Cached file is empty, deleting...');
          await cachedFile.delete();
        }
      }

      // Download file
      print('⬇️ Downloading from: $fileUrl');
      final response = await http.get(
        Uri.parse(fileUrl),
        headers: {
          'Accept': '*/*',
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📦 Response size: ${response.bodyBytes.length} bytes');

      if (response.statusCode == 200) {
        if (response.bodyBytes.isEmpty) {
          print('❌ Downloaded file is empty');
          return null;
        }

        await cachedFile.writeAsBytes(response.bodyBytes);
        print('✅ File downloaded successfully: $cachedPath');
        return cachedPath;
      } else {
        print('❌ Download failed with status: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('💥 Error ensuring local file: $e');
      return null;
    }
  }

  static void _openImageViewer(BuildContext context, String imageUrl, String fileName) {
    print('🖼️ Opening image viewer for: $imageUrl');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(
          imageUrl: imageUrl,
          fileName: fileName,
        ),
      ),
    );
  }

  static void _openPdfViewer(BuildContext context, String filePath, String fileName) {
    print('📄 Opening PDF viewer for: $filePath');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          filePath: filePath,
          fileName: fileName,
        ),
      ),
    );
  }

  static void _openVideoPlayer(BuildContext context, String filePath, String fileName) {
    print('🎬 Opening video player for: $filePath');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          filePath: filePath,
          fileName: fileName,
        ),
      ),
    );
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
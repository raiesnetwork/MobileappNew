import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';

class Base64VideoWidget extends StatefulWidget {
  final String base64Video;

  const Base64VideoWidget({super.key, required this.base64Video});

  @override
  State<Base64VideoWidget> createState() => _Base64VideoWidgetState();
}

class _Base64VideoWidgetState extends State<Base64VideoWidget> {
  late VideoPlayerController _controller;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      // Decode base64 to bytes
      final bytes = base64Decode(widget.base64Video);

      // Save to temp file
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/temp_video.mp4');
      await file.writeAsBytes(bytes);

      // Initialize the video controller
      _controller = VideoPlayerController.file(file);
      await _controller.initialize();
      _controller.setLooping(true);

      setState(() {
        isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return isInitialized
        ? Column(
            children: [
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    if (!_controller.value.isPlaying)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _controller.play();
                          });
                        },
                        child: const Icon(Icons.play_circle_fill,
                            size: 60, color: Colors.white),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _controller.pause();
                          });
                        },
                        child: Container(color: Colors.transparent),
                      ),
                  ],
                ),
              ),
            ],
          )
        : const Center(child: CircularProgressIndicator());
  }
}

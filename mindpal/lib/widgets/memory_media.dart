import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// A stored photo, loaded from the media store when it is first shown.
///
/// Three states, all handled: loading (a soft placeholder), loaded (the
/// photo), gone (a calm "photo not available" — never an exception, because
/// a file can be missing for reasons the user cannot fix).
class MemoryPhoto extends StatelessWidget {
  const MemoryPhoto({
    super.key,
    required this.load,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = AppSizes.radius,
  });

  /// Deferred on purpose: a list of twenty cards must not read twenty files
  /// before it can draw. Each card reads its own photo when it is built.
  final Future<Uint8List?> Function() load;

  final double? height;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: FutureBuilder<Uint8List?>(
          future: load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ColoredBox(color: AppColors.primarySoft);
            }
            final bytes = snapshot.data;
            if (bytes == null) return const _MediaUnavailable(label: 'Photo not available');

            return Image.memory(
              bytes,
              fit: fit,
              // Decoding at display size keeps a 12-megapixel photo from
              // costing 48 MB of RAM per card on a 2 GB phone.
              cacheWidth: 1200,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  const _MediaUnavailable(label: 'Photo could not be shown'),
            );
          },
        ),
      ),
    );
  }
}

/// A stored video with a big play button. Never autoplays.
///
/// The player is created only when the user taps play: a video controller
/// holds a decoder, and holding one for every card in a list would exhaust
/// a phone quickly. Until then this is a still poster with a play icon.
class MemoryVideoPlayer extends StatefulWidget {
  const MemoryVideoPlayer({super.key, required this.createController});

  /// Returns null if the video cannot be played (file gone, or the platform
  /// store has no player). Shown as "video not available".
  final Future<VideoPlayerController?> Function() createController;

  @override
  State<MemoryVideoPlayer> createState() => _MemoryVideoPlayerState();
}

class _MemoryVideoPlayerState extends State<MemoryVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _unavailable = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final controller = await widget.createController();
      if (controller == null) throw StateError('no player');
      await controller.initialize();
      // Re-draw on every frame position change so the play/pause icon and
      // the progress bar stay current.
      controller.addListener(_onTick);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
      await controller.play();
    } catch (error) {
      debugPrint('Video could not be started: ${error.runtimeType}');
      if (mounted) {
        setState(() {
          _loading = false;
          _unavailable = true;
        });
      }
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      // Tapping play on a finished video starts it over.
      if (controller.value.position >= controller.value.duration) {
        controller.seekTo(Duration.zero);
      }
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: _MediaUnavailable(label: 'Video not available'),
      );
    }

    final controller = _controller;
    if (controller == null) {
      // The poster: no decoder yet, just an invitation to play.
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Material(
          color: const Color(0xFF1B2B28),
          borderRadius: BorderRadius.circular(AppSizes.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _start,
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const _PlayBadge(icon: Icons.play_arrow_rounded, label: 'Play video'),
            ),
          ),
        ),
      );
    }

    final isPlaying = controller.value.isPlaying;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radius),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            // A full-surface tap target, so the user never has to hit a
            // small icon to pause.
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _togglePlay,
                  child: AnimatedOpacity(
                    // Hidden while playing so it does not sit over the
                    // video; back the moment it pauses.
                    opacity: isPlaying ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: const Center(
                      child: _PlayBadge(icon: Icons.play_arrow_rounded, label: 'Play'),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.only(top: 12),
                colors: const VideoProgressColors(
                  playedColor: AppColors.primary,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 56, color: Colors.white),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MediaUnavailable extends StatelessWidget {
  const _MediaUnavailable({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSizes.gap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            size: AppSizes.iconLarge,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSizes.gapSmall),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

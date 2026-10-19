import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/stream_state.dart';
import '../providers.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String streamUrl;
  final String title;
  final String infoHash;
  final int fileIndex;
  final int totalLength;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    required this.infoHash,
    required this.fileIndex,
    required this.totalLength,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _controlsLocked = false;
  bool _showStats = false;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _player = Player();
    _controller = VideoController(_player);

    // Enter immersive fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Restore last resume position if available
    final db = ref.read(databaseProvider);
    final resume = await db.getResumePosition(widget.infoHash, widget.fileIndex);
    final resumeMs = (resume?['position_ms'] as num?)?.toInt() ?? 0;

    await _player.open(Media(widget.streamUrl), play: true);

    if (resumeMs > 5000) {
      await _player.seek(Duration(milliseconds: resumeMs));
    }

    _player.stream.position.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
        // Persist resume position periodically
        if (pos.inSeconds % 5 == 0 && _duration.inMilliseconds > 0) {
          db.saveResumePosition(
            infoHash: widget.infoHash,
            fileIndex: widget.fileIndex,
            positionMs: pos.inMilliseconds,
            durationMs: _duration.inMilliseconds,
          );
        }
      }
    });

    _player.stream.duration.listen((dur) {
      if (mounted && dur != Duration.zero) {
        setState(() => _duration = dur);
      }
    });

    _player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() => _isBuffering = buffering);
      }
    });

    _resetHideControlsTimer();
  }

  @override
  void dispose() {
    // Restore UI overlays
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    _hideControlsTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_showControls && !_controlsLocked) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) _resetHideControlsTimer();
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(streamTelemetryProvider).value;
    final streamState = ref.watch(streamStateProvider).value;
    final isStreamingBuffering = streamState is StreamStateBuffering || _isBuffering;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onDoubleTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 2) {
            // Skip back 10s
            _player.seek(_position - const Duration(seconds: 10));
          } else {
            // Skip forward 10s
            _player.seek(_position + const Duration(seconds: 10));
          }
        },
        onLongPressStart: (_) {
          // 2x speed boost on long press
          _player.setRate(2.0);
        },
        onLongPressEnd: (_) {
          // Restore user speed
          _player.setRate(_playbackSpeed);
        },
        child: Stack(
          children: [
            // Video Surface
            Center(
              child: Video(
                controller: _controller,
                controls: NoVideoControls,
              ),
            ),

            // Adaptive Buffering Indicator with Swarm Telemetry
            if (isStreamingBuffering)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: AppTheme.primaryAccent,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Buffering Video Pieces...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (telemetry != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${telemetry.downloadSpeedMBps.toStringAsFixed(2)} MB/s • ${telemetry.activePeers} peers • ${telemetry.seedCount} seeds',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Stats for Geeks Overlay
            if (_showStats && telemetry != null)
              Positioned(
                top: 70,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SWARM TELEMETRY',
                        style: TextStyle(
                          color: AppTheme.primaryAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Download: ${telemetry.downloadSpeedMBps.toStringAsFixed(2)} MB/s',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                      Text(
                        'Upload: ${telemetry.uploadSpeedKBps.toStringAsFixed(1)} KB/s',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                      Text(
                        'Seeds / Peers: ${telemetry.seedCount} / ${telemetry.activePeers}',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                      Text(
                        'Buffer Ahead: ${(telemetry.bufferAheadBytes / (1024 * 1024)).toStringAsFixed(1)} MB (${telemetry.bufferAheadSeconds.toStringAsFixed(1)}s)',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),

            // Player Overlay Controls
            if (_showControls) ...[
              // Top Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _showStats ? Icons.analytics_rounded : Icons.analytics_outlined,
                            color: _showStats ? AppTheme.primaryAccent : Colors.white,
                          ),
                          tooltip: 'Stats Overlay',
                          onPressed: () {
                            setState(() => _showStats = !_showStats);
                            _resetHideControlsTimer();
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _controlsLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                            color: _controlsLocked ? AppTheme.primaryAccent : Colors.white,
                          ),
                          tooltip: 'Lock Controls',
                          onPressed: () {
                            setState(() => _controlsLocked = !_controlsLocked);
                            _resetHideControlsTimer();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Center Play/Pause & Skip Buttons
              if (!_controlsLocked)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 42,
                        icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                        onPressed: () {
                          _player.seek(_position - const Duration(seconds: 10));
                          _resetHideControlsTimer();
                        },
                      ),
                      const SizedBox(width: 32),
                      StreamBuilder<bool>(
                        stream: _player.stream.playing,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? true;
                          return Container(
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryAccent,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              iconSize: 54,
                              icon: Icon(
                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                isPlaying ? _player.pause() : _player.play();
                                _resetHideControlsTimer();
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 32),
                      IconButton(
                        iconSize: 42,
                        icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                        onPressed: () {
                          _player.seek(_position + const Duration(seconds: 10));
                          _resetHideControlsTimer();
                        },
                      ),
                    ],
                  ),
                ),

              // Bottom Bar
              if (!_controlsLocked)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Scrubber Slider
                          Row(
                            children: [
                              Text(
                                _formatDuration(_position),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _duration.inMilliseconds > 0
                                      ? (_position.inMilliseconds / _duration.inMilliseconds)
                                          .clamp(0.0, 1.0)
                                      : 0.0,
                                  onChanged: (val) {
                                    final targetMs = (val * _duration.inMilliseconds).toInt();
                                    _player.seek(Duration(milliseconds: targetMs));
                                    _resetHideControlsTimer();
                                  },
                                ),
                              ),
                              Text(
                                _formatDuration(_duration),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),

                          // Controls Row (Speed, Audio, Subtitles, Volume)
                          Row(
                            children: [
                              // Speed Picker
                              TextButton(
                                onPressed: () {
                                  _resetHideControlsTimer();
                                  _showSpeedPicker();
                                },
                                child: Text(
                                  '${_playbackSpeed}x',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Volume Slider
                              const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                              SizedBox(
                                width: 100,
                                child: Slider(
                                  value: _volume,
                                  onChanged: (v) {
                                    setState(() => _volume = v);
                                    _player.setVolume(v * 100);
                                    _resetHideControlsTimer();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSpeedPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
            return ListTile(
              title: Text('${speed}x Speed'),
              trailing: _playbackSpeed == speed
                  ? const Icon(Icons.check_rounded, color: AppTheme.primaryAccent)
                  : null,
              onTap: () {
                setState(() => _playbackSpeed = speed);
                _player.setRate(speed);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

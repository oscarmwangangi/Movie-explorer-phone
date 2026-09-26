import 'dart:async';
import 'dart:io' show Platform, Directory;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:window_manager/window_manager.dart';
import 'package:movie_explorer/main.dart';

/// Full-screen trailer playback for a single YouTube video.
class TrailerPlayerScreen extends StatefulWidget {
  final String youtubeKey;
  final String title;

  const TrailerPlayerScreen({
    required this.youtubeKey,
    required this.title,
    super.key,
  });

  @override
  State<TrailerPlayerScreen> createState() => _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState extends State<TrailerPlayerScreen> with WindowListener {
  // Mobile path (youtube_player_flutter has native platform support there).
  YoutubePlayerController? _controller;

  // Windows path — youtube_player_flutter's embedded webview has no
  // Windows implementation, but flutter_inappwebview (Edge WebView2) does,
  // so we load YouTube's own embed player URL directly.
  InAppWebViewController? _winController;
  WebViewEnvironment? _webViewEnvironment;
  bool _winInitFailed = false;
  bool _winLoading = true;
  bool _isFullScreen = false;
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isMinimized = false;

  bool get _isWindows => !kIsWeb && Platform.isWindows;
  bool get _isLinux => !kIsWeb && Platform.isLinux;

  @override
  void initState() {
    super.initState();

    if (_isWindows) {
      windowManager.addListener(this);
      _initWindowsWebview();
      return;
    }

    // Linux has no maintained in-app webview option here — genuine gap,
    // handled with an honest browser-fallback screen below.
    if (_isLinux) return;

    _controller = YoutubePlayerController(
      initialVideoId: widget.youtubeKey,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        forceHD: false,
      ),
    );
  }

  Future<void> _initWindowsWebview() async {
    if (!Platform.isWindows) return;

    if (globalWebViewEnvironment != null) {
      _webViewEnvironment = globalWebViewEnvironment;
      if (mounted) {
        setState(() {
          _winLoading = false;
        });
      }
    } else {
      try {
        final String? localAppData = Platform.environment['LOCALAPPDATA'];
        final String userDataFolder = localAppData != null
            ? "$localAppData\\MovieExplorer\\webview_data"
            : "${Directory.systemTemp.path}\\MovieExplorer\\webview_data";

        await Directory(userDataFolder).create(recursive: true);

        _webViewEnvironment = await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(userDataFolder: userDataFolder),
        );

        if (mounted) {
          setState(() {
            _winLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error initializing WebView2 environment: $e");
        if (mounted) {
          setState(() {
            _winInitFailed = true;
            _winLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    if (_isWindows) {
      windowManager.removeListener(this);
    }
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void onWindowMinimize() {
    if (mounted && _isWindows) {
      setState(() {
        _isMinimized = true;
      });
      // Try to pause video playback when minimized
      _winController?.evaluateJavascript(source: """
        (function() {
          var vids = document.getElementsByTagName('video');
          for (var i = 0; i < vids.length; i++) vids[i].pause();
        })();
      """);
    }
  }

  @override
  void onWindowRestore() {
    if (mounted && _isWindows) {
      setState(() {
        _isMinimized = false;
      });
      // Try to resume video playback when restored
      _winController?.evaluateJavascript(source: """
        (function() {
          var vids = document.getElementsByTagName('video');
          for (var i = 0; i < vids.length; i++) vids[i].play();
        })();
      """);
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse("https://www.youtube.com/watch?v=${widget.youtubeKey}");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _toggleRotation() {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  Future<void> _toggleWindowsFullScreen() async {
    bool nowFull = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!nowFull);
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        _isFullScreen = !nowFull;
        if (_isFullScreen) _startHideTimer();
      });
    }
  }

  Future<void> _exitWindowsFullScreen() async {
    if (_isWindows && _isFullScreen) {
      await windowManager.setFullScreen(false);
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _isFullScreen = false;
          _showControls = true;
        });
      }
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isFullScreen) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onMouseMoved() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    if (_isFullScreen) {
      _startHideTimer();
    }
  }

  Widget _buildBrowserFallback(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.open_in_new, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.play_arrow),
              label: const Text("Watch trailer"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (_isWindows) {
      Widget body;
      if (_winInitFailed) {
        body = _buildBrowserFallback(
          "Couldn't start the in-app player (WebView2 Runtime may be missing).",
        );
      } else if (_winLoading || _webViewEnvironment == null) {
        body = const Center(child: CircularProgressIndicator(color: AppColors.accent));
      } else {
        body = MouseRegion(
          onHover: (_) => _onMouseMoved(),
          child: Stack(
            children: [
              InAppWebView(
                  webViewEnvironment: _webViewEnvironment,
                  initialUrlRequest: URLRequest(
                    url: WebUri("https://www.youtube.com/embed/${widget.youtubeKey}?autoplay=1"),
                  ),
                initialSettings: InAppWebViewSettings(
                  transparentBackground: false, // Prevents freeze during full-screen resize
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  javaScriptEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: false,
                  supportMultipleWindows: false,
                ),
                onWebViewCreated: (controller) {
                  _winController = controller;
                },
                onLoadStart: (controller, url) {
                  setState(() => _winLoading = true);
                },
                onLoadStop: (controller, url) {
                  setState(() => _winLoading = false);
                },
                onCreateWindow: (controller, createWindowAction) async {
                  return false;
                },
              ),
              // Floating exit button for Full Screen
              if (_isWindows && _isFullScreen && _showControls)
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
                      tooltip: "Exit Full Screen (Esc)",
                      onPressed: _exitWindowsFullScreen,
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      return KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            _exitWindowsFullScreen();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: _isFullScreen
              ? null
              : AppBar(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: Text(
                    widget.title,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: Colors.white,
                      ),
                      onPressed: _toggleWindowsFullScreen,
                    ),
                  ],
                ),
          body: body,
        ),
      );
    }

    if (_isLinux) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: _buildBrowserFallback("Trailer opens in your browser on Linux."),
      );
    }

    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      },
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.accent,
        progressColors: const ProgressBarColors(
          playedColor: AppColors.accent,
          handleColor: AppColors.accent,
        ),
      ),
      builder: (context, player) => Scaffold(
        backgroundColor: Colors.black,
        appBar: isLandscape
            ? null
            : AppBar(
                backgroundColor: Colors.black,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                    Navigator.of(context).pop();
                  },
                ),
                title: Text(
                  widget.title,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.screen_rotation, color: Colors.white),
                    onPressed: _toggleRotation,
                  ),
                ],
              ),
        body: Center(child: player),
      ),
    );
  }
}

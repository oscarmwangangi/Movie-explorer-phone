import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform, Directory;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart' hide WebResourceResponse;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:window_manager/window_manager.dart';
import 'package:movie_explorer/main.dart';
import 'package:movie_explorer/appUI/services/watch_history_service.dart';
import 'package:movie_explorer/appUI/services/tmdb_service.dart';
import 'package:movie_explorer/appUI/home/movie_details.dart';

class ServerOption {
  final String name;
  final String movieUrl;
  final String tvUrl;

  const ServerOption({
    required this.name,
    required this.movieUrl,
    required this.tvUrl,
  });
}

final List<ServerOption> kServerOptions = [
  const ServerOption(
    name: 'VidLink (Ad-Free)',
    movieUrl: 'https://vidlink.pro/movie',
    tvUrl: 'https://vidlink.pro/tv',
  ),
  const ServerOption(
    name: 'VidSrc.cc',
    movieUrl: 'https://vidsrc.cc/v2/embed/movie',
    tvUrl: 'https://vidsrc.cc/v2/embed/tv',
  ),
  const ServerOption(
    name: 'Embed.su',
    movieUrl: 'https://embed.su/embed/movie',
    tvUrl: 'https://embed.su/embed/tv',
  ),
  const ServerOption(
    name: 'AutoEmbed',
    movieUrl: 'https://player.autoembed.cc/embed/movie',
    tvUrl: 'https://player.autoembed.cc/embed/tv',
  ),
  const ServerOption(
    name: 'VidSrc.me',
    movieUrl: 'https://vidsrc.me/embed/movie',
    tvUrl: 'https://vidsrc.me/embed/tv',
  ),
  const ServerOption(
    name: 'VidSrc.to',
    movieUrl: 'https://vidsrc.to/embed/movie',
    tvUrl: 'https://vidsrc.to/embed/tv',
  ),
  const ServerOption(
    name: '2Embed',
    movieUrl: 'https://www.2embed.cc/embed',
    tvUrl: 'https://www.2embed.cc/embedtv',
  ),
];

class MoviePlayerScreen extends StatefulWidget {
  final int tmdbId;
  final String title;
  final String? seriesName; // Added for TV show context
  final bool isTv;
  final int season;
  final int episode;
  final String? posterPath;
  final String? backdropPath;
  final num? voteAverage;

  const MoviePlayerScreen({
    required this.tmdbId,
    required this.title,
    this.seriesName,
    this.isTv = false,
    this.season = 1,
    this.episode = 1,
    this.posterPath,
    this.backdropPath,
    this.voteAverage,
    super.key,
  });

  @override
  State<MoviePlayerScreen> createState() => _MoviePlayerScreenState();
}

class _MoviePlayerScreenState extends State<MoviePlayerScreen> with WindowListener {
  // Mobile/macOS path (webview_flutter has native platform support there).
  WebViewController? _controller;

  // Windows path — flutter_inappwebview handles the WebView2 environment
  InAppWebViewController? _winController;
  WebViewEnvironment? _webViewEnvironment;
  bool _winInitFailed = false;
  bool _hasLoadedOnce = false;
  bool _isFullScreen = false;
  bool _showControls = true;
  Timer? _hideTimer;
  Timer? _mobileSafetyTimer;

  int _selectedServerIndex = 0;
  bool isLoading = true;
  double loadingProgress = 0;
  late String _playerUrl;

  // TV Navigation State
  List _seasons = [];
  List _episodes = [];
  late int _currentSeason;
  late int _currentEpisode;
  bool _isLoadingTVData = false;
  String? _tvName;

  bool get _isWindows => !kIsWeb && Platform.isWindows;
  bool get _isLinux => !kIsWeb && Platform.isLinux;

  static const String _cleanupScript = """
    (function() {
      // 1. Mock window proxy to trick popup detection scripts
      var dummyWindow = {
        closed: false,
        focus: function() {},
        blur: function() {},
        close: function() { this.closed = true; },
        postMessage: function() {},
        location: {
          href: 'about:blank',
          replace: function() {},
          assign: function() {},
          reload: function() {}
        },
        document: {
          write: function() {},
          writeln: function() {},
          open: function() {},
          close: function() {}
        }
      };

      var dummyWindowProxy = new Proxy(dummyWindow, {
        get: function(target, prop) {
          if (prop === 'closed') return false;
          if (prop in target) return target[prop];
          return function() {};
        },
        set: function(target, prop, value) {
          return true;
        }
      });

      function fakeWindowOpen() {
        return dummyWindowProxy;
      }

      function disablePopups(win) {
        try {
          try {
            Object.defineProperty(win, 'open', { value: fakeWindowOpen, writable: false, configurable: false });
          } catch(e) { win.open = fakeWindowOpen; }

          try {
            Object.defineProperty(win, 'alert', { value: function() {}, writable: false, configurable: false });
          } catch(e) { win.alert = function() {}; }

          try {
            Object.defineProperty(win, 'confirm', { value: function() { return true; }, writable: false, configurable: false });
          } catch(e) { win.confirm = function() { return true; }; }

          try {
            Object.defineProperty(win, 'prompt', { value: function() { return null; }, writable: false, configurable: false });
          } catch(e) { win.prompt = function() { return null; }; }
        } catch(e) {}
      }

      disablePopups(window);

      // 2. Prevent iframes from redirecting top window
      try {
        if (window.self !== window.top) {
          var fakeTop = new Proxy(window.self, {
            get: function(target, prop) {
              if (prop === 'location') {
                return {
                  get href() { return window.location.href; },
                  set href(val) {},
                  replace: function() {},
                  assign: function() {},
                  reload: function() {}
                };
              }
              return target[prop];
            },
            set: function(target, prop, val) {
              if (prop === 'location') return true;
              target[prop] = val;
              return true;
            }
          });

          try { Object.defineProperty(window, 'top', { get: function() { return fakeTop; } }); } catch(e) {}
          try { Object.defineProperty(window, 'parent', { get: function() { return fakeTop; } }); } catch(e) {}
        }
      } catch(e) {}

      // 3. Intercept dynamic script tag creation for ad networks
      try {
        var adDomains = ['alwingulla', 'adsterra', 'monetag', 'propeller', 'exoclick', 'juicyads', 'hilltopads', 'popunder', 'syndication', 'highrevenuegate', 'profitcpm'];
        var origCreateElement = Document.prototype.createElement;
        Document.prototype.createElement = function(tagName) {
          var el = origCreateElement.apply(this, arguments);
          if (tagName && typeof tagName === 'string' && tagName.toLowerCase() === 'script') {
            var origSetAttribute = el.setAttribute;
            el.setAttribute = function(name, value) {
              if (name === 'src' && typeof value === 'string') {
                var valLower = value.toLowerCase();
                for (var i = 0; i < adDomains.length; i++) {
                  if (valLower.includes(adDomains[i])) return;
                }
              }
              return origSetAttribute.apply(this, arguments);
            };
          }
          return el;
        };
      } catch(e) {}

      function isAllowedUrl(href) {
        var h = (href || '').toLowerCase();
        return h.includes('vidlink') || h.includes('vidsrc') || h.includes('vsembed') || 
               h.includes('2embed') || h.includes('autoembed') || h.includes('vidplay') || 
               h.includes('megacloud') || h.includes('embed.su') || h.includes('google') || 
               h.includes('cloudflare') || h.startsWith('/') || h.startsWith('#') || h === '';
      }

      function injectAdBlockStyles() {
        try {
          if (document.getElementById('app-loader-override-style')) return;
          var style = document.createElement('style');
          style.id = 'app-loader-override-style';
          style.innerHTML = `
            html, body {
              width: 100% !important;
              height: 100% !important;
              margin: 0 !important;
              padding: 0 !important;
              overflow: hidden !important;
              background-color: #000 !important;
              -webkit-tap-highlight-color: transparent !important;
            }

            video {
              width: 100% !important;
              height: 100% !important;
              max-width: 100% !important;
              max-height: 100% !important;
              object-fit: contain !important;
            }

            .loading, .spinner, #loading, #spinner,
            .loading-pulse, .pulse, .pulse-loader, .pulse-ring, .circle-pulse,
            .vjs-loading-spinner, .jw-spinner, .plyr__spinner,
            .player-loading, #player-loading, .loading-container, .loading-overlay, #player_overlay,
            div[class*="loading"], div[class*="spinner"], div[class*="pulse"], div[class*="loader"],
            div[id*="ad"], div[class*="ad-"], div[class*="ad_"], div[class*="ads"], div[class*="banner"],
            iframe[src*="ad"], iframe[src*="doubleclick"], iframe[src*="pop"], iframe[src*="bet"],
            #pop, .popunder, .popup, #popup, div[class*="popunder"], div[class*="popup"],
            a[target="_blank"][href*="http"] {
              display: none !important;
              visibility: hidden !important;
              opacity: 0 !important;
              pointer-events: none !important;
            }
          `;
          (document.head || document.documentElement).appendChild(style);
        } catch(e) {}
      }

      function removeFloatingAdOverlays() {
        try {
          var elems = document.querySelectorAll('body > div, body > aside, body > section');
          for (var i = 0; i < elems.length; i++) {
            var el = elems[i];

            // Protect video player and controls from being removed
            var hasMedia = el.querySelector('video, iframe[src*="embed"], iframe[src*="vid"], canvas');
            if (hasMedia) continue;

            var isControls = el.querySelector('button, input, [class*="control"], [class*="player"], [class*="vidlink"], [class*="vjs"], [class*="jw"], [class*="plyr"]');
            if (isControls) continue;

            var text = (el.textContent || '').toLowerCase();
            if (text.includes('missed video call') || text.includes('missed call') || 
                text.includes('has something to show') || text.includes('video call') ||
                text.includes('elina') || text.includes('incoming call') ||
                text.includes('new message') || text.includes('show to you') || 
                text.includes('chat with') || text.includes('live cam')) {
              el.style.setProperty('display', 'none', 'important');
              el.style.setProperty('pointer-events', 'none', 'important');
              el.remove();
            }
          }
        } catch(e) {}
      }

      function purgeDomNode(node) {
        if (!node || !node.tagName) return;
        try {
          var tag = node.tagName.toUpperCase();

          var text = (node.textContent || '').toLowerCase();
          if (text.includes('missed video call') || text.includes('missed call') || 
              text.includes('has something to show') || text.includes('video call') ||
              text.includes('elina') || text.includes('incoming call') ||
              text.includes('new message') || text.includes('show to you') || 
              text.includes('chat with') || text.includes('live cam')) {
            node.style.setProperty('display', 'none', 'important');
            node.style.setProperty('visibility', 'hidden', 'important');
            node.style.setProperty('pointer-events', 'none', 'important');
            node.remove();
            return;
          }

          if (tag === 'A') {
            var href = (node.getAttribute('href') || '').toLowerCase();
            var target = node.getAttribute('target');
            if (target === '_blank' || (href.startsWith('http') && !isAllowedUrl(href))) {
              node.removeAttribute('target');
              node.setAttribute('href', 'javascript:void(0)');
              node.onclick = function(e) {
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();
                return false;
              };
            }
          } else if (tag === 'IFRAME') {
            var src = (node.src || '').toLowerCase();
            if (src && !isAllowedUrl(src) && !src.includes('about:blank') && !src.includes('hcaptcha') && !src.includes('recaptcha')) {
              node.remove();
            }
          }
        } catch(e) {}

        try {
          if (node.shadowRoot) {
            var sElems = node.shadowRoot.querySelectorAll('*');
            for (var i = 0; i < sElems.length; i++) purgeDomNode(sElems[i]);
          }
        } catch(e) {}
      }

      function purgeLoadersAndAds() {
        disablePopups(window);
        injectAdBlockStyles();
        removeFloatingAdOverlays();

        try {
          var links = document.querySelectorAll('a[target="_blank"], iframe[src*="ad"]');
          for (var i = 0; i < links.length; i++) {
            purgeDomNode(links[i]);
          }
        } catch(e) {}
      }

      // Capture phase listener
      try {
        if (!window._adClickBlockerSet) {
          window._adClickBlockerSet = true;
          window.addEventListener('click', function(e) {
            disablePopups(window);
            removeFloatingAdOverlays();
            var target = e.target;
            while (target && target !== document.body) {
              if (target.tagName === 'A') {
                var href = (target.getAttribute('href') || '').toLowerCase();
                var isTargetBlank = target.getAttribute('target') === '_blank';
                if ((isTargetBlank || href.includes('ad') || href.includes('pop') || href.includes('click')) && !isAllowedUrl(href)) {
                  e.preventDefault();
                  e.stopPropagation();
                  e.stopImmediatePropagation();
                  return false;
                }
              }
              target = target.parentElement;
            }
          }, true);
        }
      } catch(e) {}

      // Override HTMLAnchorElement.prototype.click
      try {
        if (!window._anchorClickOverridden) {
          window._anchorClickOverridden = true;
          var originalClick = HTMLAnchorElement.prototype.click;
          HTMLAnchorElement.prototype.click = function() {
            var href = (this.getAttribute('href') || '').toLowerCase();
            var target = this.getAttribute('target');
            if (target === '_blank' || !isAllowedUrl(href)) {
              return;
            }
            return originalClick.apply(this, arguments);
          };
        }
      } catch(e) {}

      injectAdBlockStyles();
      purgeLoadersAndAds();

      if (!window._loaderIntervalSet) {
        window._loaderIntervalSet = true;
        setInterval(purgeLoadersAndAds, 100);
      }

      try {
        if (!window._observerSet) {
          window._observerSet = true;
          var observer = new MutationObserver(function() {
            purgeLoadersAndAds();
          });
          observer.observe(document.body || document.documentElement, { childList: true, subtree: true });
        }
      } catch(e) {}
    })();
  """;

  @override
  void initState() {
    super.initState();
    _currentSeason = widget.season;
    _currentEpisode = widget.episode;
    _tvName = widget.seriesName;

    if (_isWindows) {
      windowManager.addListener(this);
    } else if (!_isLinux) {
      // Mobile: Enable immersive mode but don't force landscape automatically
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    _updatePlayerUrl();
    _recordWatch();

    if (widget.isTv) {
      _fetchTVData();
    }

    if (_isWindows) {
      _initWindowsWebview();
      return;
    }

    if (_isLinux) {
      isLoading = false;
      return;
    }

    final String userAgent = !kIsWeb && Platform.isIOS
        ? "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        : "Mozilla/5.0 (Linux; Android 13; SM-S901B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36";

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(userAgent)
      ..addJavaScriptChannel(
        'ControlChannel',
        onMessageReceived: (message) {
          if (message.message == 'toggleControls') {
            _toggleControls();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                loadingProgress = progress / 100;
                if (progress > 80) {
                  isLoading = false;
                  _hasLoadedOnce = true;
                  _mobileSafetyTimer?.cancel();
                }
              });
              if (progress > 10) {
                _controller?.runJavaScript(_cleanupScript);
              }
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              if (!_hasLoadedOnce) {
                setState(() => isLoading = true);
              }
              _mobileSafetyTimer?.cancel();
              _mobileSafetyTimer = Timer(const Duration(seconds: 15), () {
                if (mounted && isLoading) {
                  setState(() => isLoading = false);
                }
              });
            }
            _controller?.runJavaScript(_cleanupScript);
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                isLoading = false;
                _hasLoadedOnce = true;
              });
              _mobileSafetyTimer?.cancel();
            }
            _controller?.runJavaScript(_cleanupScript);
          },
          onNavigationRequest: (NavigationRequest request) {
            final String url = request.url.toLowerCase();

            final adKeywords = [
              "adsterra", "monetag", "alwingulla", "propeller", "exoclick",
              "juicyads", "hilltopads", "syndication", "doubleclick",
              "bet365", "1xbet", "casino", "popunder", "popup",
              "click.", "redirect", "traffic", "zedo", "outbrain", "taboola",
              "ad.", "ads.", "banner", "pop.", "track", "analytic", "clicker",
              "onclick", "creative", "affiliate", "promo", "lead", "spin", "win",
              "gift", "bonus", "betting", "poker", "slot", "highrevenuegate",
              "profitcpm", "onclickads"
            ];
            if (adKeywords.any((kw) => url.contains(kw))) {
              debugPrint("Blocked explicit ad URL: $url");
              return NavigationDecision.prevent;
            }

            final playerUri = Uri.tryParse(_playerUrl);
            final playerHost = playerUri?.host.toLowerCase();

            // Protection against post-load main frame redirects
            if (_hasLoadedOnce) {
              final reqUri = Uri.tryParse(url);
              final reqHost = reqUri?.host.toLowerCase();
              if (playerHost != null && reqHost != null && playerHost != reqHost && !url.contains(widget.tmdbId.toString())) {
                debugPrint("Blocked post-load main frame redirect to: $url");
                return NavigationDecision.prevent;
              }
            }

            final allowedDomains = [
              "vidsrc", "vsembed", "2embed", "autoembed", "vidplay",
              "megacloud", "vizcloud", "rabbitstream", "cloudnest",
              "movie-api", "mcloud", "filemoon", "streamtape", "embed.su",
              "vidlink", "superstream", "google.com", "gstatic.com", "cloudflare",
              "hcaptcha", "recaptcha"
            ];

            bool isAllowed = allowedDomains.any((domain) => url.contains(domain)) ||
                (playerHost != null && playerHost.isNotEmpty && url.contains(playerHost));

            if (isAllowed || url == _playerUrl.toLowerCase()) {
              return NavigationDecision.navigate;
            }

            debugPrint("Blocked navigation to: $url");
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(_playerUrl));
  }

  void _updatePlayerUrl() {
    final server = kServerOptions[_selectedServerIndex];
    String url;
    if (server.name.contains('VidLink')) {
      url = widget.isTv
          ? "${server.tvUrl}/${widget.tmdbId}/$_currentSeason/$_currentEpisode?primaryColor=E8894D"
          : "${server.movieUrl}/${widget.tmdbId}?primaryColor=E8894D";
    } else if (server.name == '2Embed') {
      url = widget.isTv
          ? "${server.tvUrl}/${widget.tmdbId}&s=$_currentSeason&e=$_currentEpisode"
          : "${server.movieUrl}/${widget.tmdbId}";
    } else {
      url = widget.isTv
          ? "${server.tvUrl}/${widget.tmdbId}/$_currentSeason/$_currentEpisode"
          : "${server.movieUrl}/${widget.tmdbId}";
    }

    setState(() {
      _playerUrl = url;
    });
  }

  void _changeServer(int index) {
    if (index == _selectedServerIndex) return;
    setState(() {
      _selectedServerIndex = index;
      isLoading = true;
      _hasLoadedOnce = false;
    });
    _updatePlayerUrl();
    if (_isWindows) {
      _winController?.loadUrl(urlRequest: URLRequest(url: WebUri(_playerUrl)));
    } else {
      _controller?.loadRequest(Uri.parse(_playerUrl));
    }
  }

  void _recordWatch() {
    String displayTitle = widget.isTv ? (_tvName ?? widget.title.split(' - ')[0]) : widget.title;
    WatchHistoryService.recordWatch(
      {
        'id': widget.tmdbId,
        'title': displayTitle,
        'name': displayTitle,
        'poster_path': widget.posterPath,
        'backdrop_path': widget.backdropPath,
        'vote_average': widget.voteAverage,
      },
      isTv: widget.isTv,
      season: widget.isTv ? _currentSeason : null,
      episode: widget.isTv ? _currentEpisode : null,
    );
  }

  Future<void> _fetchTVData() async {
    setState(() => _isLoadingTVData = true);
    try {
      final details = await TMDBService.getTVDetails(widget.tmdbId);
      if (mounted) {
        setState(() {
          _tvName = details['name'];
          _seasons = details['seasons'] as List? ?? [];
        });
        await _fetchEpisodesForSeason(_currentSeason);
      }
    } catch (e) {
      debugPrint("Error fetching TV details: $e");
    } finally {
      if (mounted) setState(() => _isLoadingTVData = false);
    }
  }

  Future<void> _fetchEpisodesForSeason(int seasonNumber) async {
    try {
      final episodes = await TMDBService.getTVSeasonEpisodes(widget.tmdbId, seasonNumber);
      if (mounted) {
        setState(() {
          _episodes = episodes;
        });
      }
    } catch (e) {
      debugPrint("Error fetching episodes: $e");
    }
  }

  void _changeEpisode(int? newEpisode) {
    if (newEpisode == null || newEpisode == _currentEpisode) return;
    setState(() {
      _currentEpisode = newEpisode;
      isLoading = true;
      _hasLoadedOnce = false;
    });
    _updatePlayerUrl();
    _recordWatch();
    if (_isWindows) {
      _winController?.loadUrl(urlRequest: URLRequest(url: WebUri(_playerUrl)));
    } else {
      _controller?.loadRequest(Uri.parse(_playerUrl));
    }
  }

  void _changeSeason(int? newSeason) async {
    if (newSeason == null || newSeason == _currentSeason) return;
    setState(() {
      _currentSeason = newSeason;
      _currentEpisode = 1;
      isLoading = true;
      _hasLoadedOnce = false;
      _episodes = [];
      _isLoadingTVData = true;
    });
    await _fetchEpisodesForSeason(newSeason);
    if (mounted) setState(() => _isLoadingTVData = false);
    _updatePlayerUrl();
    _recordWatch();
    if (_isWindows) {
      _winController?.loadUrl(urlRequest: URLRequest(url: WebUri(_playerUrl)));
    } else {
      _controller?.loadRequest(Uri.parse(_playerUrl));
    }
  }

  Future<void> _initWindowsWebview() async {
    if (!Platform.isWindows) return;

    if (globalWebViewEnvironment != null) {
      _webViewEnvironment = globalWebViewEnvironment;
      if (mounted) {
        setState(() {
          isLoading = false;
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
            isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error initializing WebView2 environment: $e");
        if (mounted) {
          setState(() {
            _winInitFailed = true;
            isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(_playerUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    if (_isWindows) {
      windowManager.removeListener(this);
    }
    _hideTimer?.cancel();
    _mobileSafetyTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void onWindowMinimize() {
    if (mounted && _isWindows) {
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
      _winController?.evaluateJavascript(source: """
        (function() {
          var vids = document.getElementsByTagName('video');
          for (var i = 0; i < vids.length; i++) vids[i].play();
        })();
      """);
    }
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
      if (mounted) {
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

  void _toggleControls() {
    if (mounted) {
      setState(() {
        _showControls = !_showControls;
        if (_showControls) {
          _startHideTimer();
        }
      });
    }
  }

  void _showInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(
          movie: {
            'id': widget.tmdbId,
            'name': _tvName ?? widget.title.split(' - ')[0],
            'poster_path': widget.posterPath,
            'backdrop_path': widget.backdropPath,
            'vote_average': widget.voteAverage,
          },
        ),
      ),
    );
  }

  void _showServerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select Player Server",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(kServerOptions.length, (index) {
                      final server = kServerOptions[index];
                      final isSelected = _selectedServerIndex == index;
                      return ListTile(
                        leading: Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? AppColors.accent : Colors.white54,
                        ),
                        title: Text(
                          server.name,
                          style: TextStyle(
                            color: isSelected ? AppColors.accent : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _changeServer(index);
                        },
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEpisodePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Episodes",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_seasons.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _seasons.map((s) {
                      bool isSelected = s['season_number'] == _currentSeason;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: ChoiceChip(
                          label: Text("Season ${s['season_number']}"),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              _changeSeason(s['season_number']);
                              Navigator.pop(context);
                            }
                          },
                          backgroundColor: AppColors.surface,
                          selectedColor: AppColors.accent,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoadingTVData
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : ListView.separated(
                  itemCount: _episodes.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final ep = _episodes[index];
                    bool isSelected = ep['episode_number'] == _currentEpisode;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "E${ep['episode_number']}: ${ep['name']}",
                        style: TextStyle(
                          color: isSelected ? AppColors.accent : Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.play_circle_fill, color: AppColors.accent) : null,
                      onTap: () {
                        _changeEpisode(ep['episode_number']);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileControls() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _showControls ? 1.0 : 0.0,
      child: Stack(
        children: [
          // Top gradient scrim
          Positioned(
            top: 0, left: 0, right: 0,
            child: IgnorePointer(
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withAlpha(204), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          // Top Bar
          Positioned(
            top: 10, left: 10, right: 10,
            child: SafeArea(
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.isTv ? (_tvName ?? widget.title) : widget.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.isTv)
                            Text(
                              "Season $_currentSeason Episode $_currentEpisode",
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.dns_outlined, color: Colors.white),
                      tooltip: "Server (${kServerOptions[_selectedServerIndex].name})",
                      onPressed: _showServerPicker,
                    ),
                    if (widget.isTv)
                      IconButton(
                        icon: const Icon(Icons.layers, color: Colors.white),
                        tooltip: "Episodes",
                        onPressed: _showEpisodePicker,
                      ),
                    IconButton(
                      icon: const Icon(Icons.screen_rotation, color: Colors.white),
                      tooltip: "Rotate Screen",
                      onPressed: _toggleRotation,
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.white),
                      onPressed: _showInfo,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
              label: const Text("Watch in browser"),
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

    Widget body;
    if (_isWindows) {
      if (_winInitFailed) {
        body = _buildBrowserFallback(
          "Couldn't start the in-app player (WebView2 Runtime may be missing).",
        );
      } else if (_webViewEnvironment == null) {
        body = const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        );
      } else {
        body = MouseRegion(
          onHover: (_) => _onMouseMoved(),
          child: Stack(
            children: [
              InAppWebView(
                webViewEnvironment: _webViewEnvironment,
                initialUrlRequest: URLRequest(url: WebUri(_playerUrl)),
                initialUserScripts: UnmodifiableListView([
                  UserScript(
                    source: _cleanupScript,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    forMainFrameOnly: false,
                  ),
                  UserScript(
                    source: _cleanupScript,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                    forMainFrameOnly: false,
                  ),
                ]),
                initialSettings: InAppWebViewSettings(
                  userAgent:
                  "Mozilla/5.0 (Linux; Android 13; SM-S901B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36",
                  preferredContentMode: UserPreferredContentMode.MOBILE,
                  transparentBackground: false,
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  javaScriptEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: false,
                  supportMultipleWindows: false,
                  isInspectable: kDebugMode,
                ),
                onWebViewCreated: (controller) {
                  _winController = controller;
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    loadingProgress = progress / 100;
                    if (progress > 80) {
                      isLoading = false;
                      _hasLoadedOnce = true;
                    }
                  });
                  if (progress > 10) {
                    controller.evaluateJavascript(source: _cleanupScript);
                  }
                },
                onLoadStart: (controller, url) {
                  if (!_hasLoadedOnce) {
                    setState(() => isLoading = true);
                  }
                  controller.evaluateJavascript(source: _cleanupScript);
                },
                onLoadStop: (controller, url) async {
                  setState(() {
                    isLoading = false;
                    _hasLoadedOnce = true;
                  });
                  await controller.evaluateJavascript(source: _cleanupScript);
                  await controller.evaluateJavascript(source: """
                    document.body.style.backgroundColor = 'black';
                    var divs = document.getElementsByTagName('div');
                    for(var i=0; i<divs.length; i++) {
                      if(divs[i].style.zIndex > 1000) divs[i].remove();
                    }
                  """);
                },
                onReceivedError: (controller, request, error) {
                  debugPrint("WebView Load Error: ${error.description} (code: ${error.type}) at ${request.url}");
                },
                onReceivedHttpError: (controller, request, errorResponse) {
                  debugPrint("WebView HTTP Error: ${errorResponse.reasonPhrase} (status: ${errorResponse.statusCode}) at ${request.url}");
                },
                onCreateWindow: (controller, createWindowAction) async {
                  return false;
                },
                shouldInterceptRequest: (controller, request) async {
                  final url = request.url.toString().toLowerCase();

                  final badAdDomains = [
                    "alwingulla", "adsterra", "monetag", "highrevenuegate", "profitcpm",
                    "exoclick", "juicyads", "hilltopads", "syndication", "propeller",
                    "popunder", "popads", "popcash", "ad-delivery", "onclickads",
                    "clickadilla", "trafficjunky", "doubleclick", "outbrain", "taboola"
                  ];

                  if (badAdDomains.any((domain) => url.contains(domain))) {
                    debugPrint("Intercepted and blocked ad resource: $url");
                    return WebResourceResponse(
                      contentType: 'text/javascript',
                      data: Uint8List(0),
                    );
                  }

                  return null;
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final uri = navigationAction.request.url;
                  if (uri == null) return NavigationActionPolicy.CANCEL;

                  final url = uri.toString().toLowerCase();

                  final adKeywords = [
                    "adsterra", "monetag", "alwingulla", "propeller", "exoclick",
                    "juicyads", "hilltopads", "syndication", "doubleclick",
                    "bet365", "1xbet", "casino", "popunder", "popup",
                    "click.", "redirect", "traffic", "zedo", "outbrain", "taboola",
                    "ad.", "ads.", "banner", "pop.", "track", "analytic", "clicker",
                    "onclick", "creative", "affiliate", "promo", "lead", "spin", "win",
                    "gift", "bonus", "betting", "poker", "slot"
                  ];
                  if (adKeywords.any((kw) => url.contains(kw))) {
                    debugPrint("Blocking explicit ad: $url");
                    return NavigationActionPolicy.CANCEL;
                  }

                  final allowedDomains = [
                    "vidsrc", "vsembed", "2embed", "autoembed", "vidplay",
                    "megacloud", "vizcloud", "rabbitstream", "cloudnest",
                    "movie-api", "mcloud", "filemoon", "streamtape", "embedsu",
                    "superstream", "google.com", "gstatic.com", "cloudflare",
                    "hcaptcha", "recaptcha"
                  ];

                  final playerUri = Uri.tryParse(_playerUrl);
                  final playerHost = playerUri?.host.toLowerCase();

                  bool isAllowed = allowedDomains.any((domain) => url.contains(domain)) ||
                      (playerHost != null && playerHost.isNotEmpty && url.contains(playerHost));

                  if (navigationAction.isForMainFrame) {
                    if (_hasLoadedOnce) {
                      final reqUri = Uri.tryParse(url);
                      final reqHost = reqUri?.host.toLowerCase();
                      if (playerHost != null && reqHost != null && playerHost != reqHost && !url.contains(widget.tmdbId.toString())) {
                        debugPrint("Blocking post-load main frame redirect to: $url");
                        return NavigationActionPolicy.CANCEL;
                      }
                    }

                    if (isAllowed || url == _playerUrl.toLowerCase()) {
                      return NavigationActionPolicy.ALLOW;
                    }
                    debugPrint("Blocking main frame redirect to: $url");
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (!isAllowed) {
                    return NavigationActionPolicy.CANCEL;
                  }

                  return NavigationActionPolicy.ALLOW;
                },
              ),
              if (isLoading)
                Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: loadingProgress > 0 ? loadingProgress : null,
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 16),
                        const Text("Loading stream...", style: TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
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
    } else if (_isLinux) {
      body = _buildBrowserFallback("Playback opens in your browser on Linux.");
    } else {
      body = Stack(
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              if (mounted) {
                setState(() {
                  _showControls = !_showControls;
                  if (_showControls) {
                    _startHideTimer();
                  } else {
                    _hideTimer?.cancel();
                  }
                });
              }
            },
            child: WebViewWidget(controller: _controller!),
          ),
          if (isLoading && !_hasLoadedOnce)
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Loading stream...",
                      style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 1.1),
                    ),
                  ],
                ),
              ),
            ),
          _buildMobileControls(),
        ],
      );
    }

    final bool useMobileOverlay = !_isWindows && !_isLinux;
    final bool hideAppBar = _isFullScreen || useMobileOverlay || (!_isWindows && !_isLinux && isLandscape);

    final playerScaffold = Scaffold(
      backgroundColor: Colors.black,
      appBar: hideAppBar
          ? null
          : AppBar(
        backgroundColor: Colors.black,
        title: widget.isTv
            ? SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text(
                "${_tvName ?? widget.title.split(' - ')[0]} · S${_currentSeason.toString().padLeft(2, '0')} E${_currentEpisode.toString().padLeft(2, '0')}",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(width: 12),
              if (_seasons.isNotEmpty)
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _seasons.any((s) => s['season_number'] == _currentSeason) ? _currentSeason : null,
                      dropdownColor: AppColors.surface,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 18),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: _seasons.map((s) {
                        return DropdownMenuItem<int>(
                          value: s['season_number'],
                          child: Text(s['season_number'] == 0 ? "Specials" : "Season ${s['season_number']}"),
                        );
                      }).toList(),
                      onChanged: _isLoadingTVData ? null : _changeSeason,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              if (_episodes.isNotEmpty)
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _episodes.any((e) => e['episode_number'] == _currentEpisode) ? _currentEpisode : null,
                      dropdownColor: AppColors.surface,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 18),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: _episodes.map((e) {
                        return DropdownMenuItem<int>(
                          value: e['episode_number'],
                          child: Text("Episode ${e['episode_number']}"),
                        );
                      }).toList(),
                      onChanged: _isLoadingTVData ? null : _changeEpisode,
                    ),
                  ),
                ),
              if (_isLoadingTVData) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
              ],
            ],
          ),
        )
            : Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            if (_isFullScreen) {
              await windowManager.setFullScreen(false);
            }
            if (!context.mounted) return;
            SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dns_outlined, color: Colors.white),
            tooltip: "Server (${kServerOptions[_selectedServerIndex].name})",
            onPressed: _showServerPicker,
          ),
          if (widget.isTv)
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              tooltip: "Series Info",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MovieDetailsScreen(
                      movie: {
                        'id': widget.tmdbId,
                        'name': _tvName ?? widget.title.split(' - ')[0],
                        'poster_path': widget.posterPath,
                        'backdrop_path': widget.backdropPath,
                        'vote_average': widget.voteAverage,
                      },
                    ),
                  ),
                );
              },
            ),
          if (_isWindows) ...[
            IconButton(
              icon: Icon(
                _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
              onPressed: _toggleWindowsFullScreen,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _winController?.reload();
              },
            ),
          ],
          if (!_isWindows && !_isLinux)
            IconButton(
              icon: const Icon(Icons.screen_rotation, color: Colors.white),
              onPressed: _toggleRotation,
            ),
        ],
      ),
      body: body,
    );

    if (_isWindows) {
      return KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            _exitWindowsFullScreen();
          }
        },
        child: playerScaffold,
      );
    }

    return playerScaffold;
  }
}

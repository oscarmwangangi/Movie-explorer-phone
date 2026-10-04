import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform, Directory;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:window_manager/window_manager.dart';
import 'package:movie_explorer/main.dart';
import 'package:movie_explorer/appUI/services/watch_history_service.dart';
import 'package:movie_explorer/appUI/services/tmdb_service.dart';
import 'package:movie_explorer/appUI/home/movie_details.dart';

// NOTE: webview_flutter is no longer used in this file.
// We use flutter_inappwebview on Windows, Android and iOS, because it
// can inject our ad-cleaning script into EVERY iframe (ads live in iframes).

// ---------------------------------------------------------------------------
// TEMP TEST SWITCH
// ---------------------------------------------------------------------------
// If a server still freezes the app, set this to false and run again.
// false = the ad-cleaning JavaScript is NOT injected at all.
// If the freeze disappears, the script is the cause.
const bool kEnableCleanupScript = true;

// ---------------------------------------------------------------------------
// Streaming servers
// ---------------------------------------------------------------------------

class ServerOption {
  final String name;
  final String movieUrl;
  final String tvUrl;

  // How the final URL is built:
  //   'path'    -> movieUrl/ID           and tvUrl/ID/SEASON/EPISODE
  //   'query'   -> movieUrl?tmdb=ID      and tvUrl?tmdb=ID&season=S&episode=E
  //   'vidlink' -> same as 'path' but with a ?primaryColor=... at the end
  final String style;

  const ServerOption({
    required this.name,
    required this.movieUrl,
    required this.tvUrl,
    this.style = 'path',
  });
}

final List<ServerOption> kServerOptions = [
  const ServerOption(
    name: 'Server 1',
    movieUrl: 'https://vidsrc.to/embed/movie',
    tvUrl: 'https://vidsrc.to/embed/tv',
    style: 'path',
  ),
  // CHANGED: Server 2 is vidsrc.me (it was vidsrc.sh before).
  // vidsrc.me uses query-style URLs: /embed/movie?tmdb=ID
  // const ServerOption(
  //   name: 'Server 2',
  //   movieUrl: 'https://vidsrc.me/embed/movie',
  //   tvUrl: 'https://vidsrc.me/embed/tv',
  //   style: 'query',
  // ),
  const ServerOption(
    name: 'Server 3 (Ad-Free) HD',
    movieUrl: 'https://vidlink.pro/movie',
    tvUrl: 'https://vidlink.pro/tv',
    style: 'vidlink',
  ),
];

// ---------------------------------------------------------------------------
// Ad blocking lists (shared by every platform)
// ---------------------------------------------------------------------------

// Names of known ad networks / betting sites. If a URL contains any of these,
// we block it.
const List<String> kAdNetworkKeywords = [
  "adsterra", "monetag", "alwingulla", "propeller", "exoclick",
  "juicyads", "hilltopads", "syndication", "doubleclick", "popunder",
  "popads", "popcash", "highrevenuegate", "profitcpm", "onclickads",
  "clickadilla", "trafficjunky", "zedo", "outbrain", "taboola",
  "bet365", "1xbet", "casino",
];

// URL paths that are almost always ads / popups.
const List<String> kAdUrlPaths = [
  "/popup", "/popunder", "/ads/", "/ad/", "/clk", "/out/",
];

// Domains the player is allowed to load from.
// If a server stops working, check the debug console for a
// "Blocking ..." message and add that domain here.
const List<String> kAllowedDomains = [
  "vidsrc", "vsembed", "2embed", "autoembed", "vidplay",
  "megacloud", "vizcloud", "rabbitstream", "cloudnest",
  "cloudorchestranova", "orchestranova", "shadowland",
  "movie-api", "mcloud", "filemoon", "streamtape", "embed.su", "embedsu",
  "vidlink", "superstream", "google.com", "gstatic.com", "cloudflare",
  "hcaptcha", "recaptcha", "smashystream", "vidsrc.cc", "vidsrc.icu",
  // CHANGED: extra domains that vidsrc.me redirects to / loads from.
  "vidsrc.me", "vidsrc.net", "vidsrc.xyz", "vidsrcme", "vidsrc-embed",
  "cloudnestra",
];

// ---------------------------------------------------------------------------
// The screen
// ---------------------------------------------------------------------------

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
  // The webview controller. Used on Windows, Android and iOS.
  InAppWebViewController? _winController;

  // Only Windows needs this (WebView2 environment). It stays null on mobile.
  WebViewEnvironment? _webViewEnvironment;

  bool _winInitFailed = false;
  bool _hasLoadedOnce = false;
  bool _isFullScreen = false;
  bool _isMinimized = false;
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

  final FocusNode _windowsFocusNode = FocusNode();

  // Pretend to be a phone browser so the players show their mobile layout.
  String get _userAgent {
    if (!kIsWeb && Platform.isIOS) {
      return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1";
    }
    return "Mozilla/5.0 (Linux; Android 13; SM-S901B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36";
  }

  // JavaScript that is injected into the player page AND all of its iframes.
  // It removes popups, fake "missed video call" boxes and ad links.
  // It is a raw string (r"""...""") so Dart does not touch $ signs inside it.
  //
  // CHANGES compared to the old version (these were the freeze risks):
  //  - Removed the window.top / window.parent Proxy (it broke player code).
  //  - The fake-call scan only looks at SMALL elements (short text) and uses
  //    textContent (cheap) instead of innerText (forces page layout).
  //  - Removed broad words like 'missed', 'video call', 'chat with' that
  //    matched normal player text and caused remove -> re-add -> remove loops.
  //  - Removed the shadow-root scan of every element on the page.
  //  - The periodic scan runs every 2 seconds instead of every 0.5 seconds.
  static const String _cleanupScript = r"""
    (function() {
      if (window.__cleanupInstalled) return;
      window.__cleanupInstalled = true;

      // 1. Fake window object for popups
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

      function fakeWindowOpen() {
        return dummyWindow;
      }

      function disablePopups() {
        try {
          window.open = fakeWindowOpen;
          window.alert = function() {};
          window.confirm = function() { return true; };
          window.prompt = function() { return null; };
        } catch(e) {}
      }

      disablePopups();

      function wakeAndResumeVideo() {
        try {
          var vids = document.querySelectorAll('video');
          for (var i = 0; i < vids.length; i++) {
            var v = vids[i];
            if (v) {
              if (v.paused && v.currentTime > 0 && !v.ended) {
                v.play().catch(function(){});
              }
              var oldTransform = v.style.transform;
              v.style.transform = 'translateZ(0)';
              setTimeout(function() { v.style.transform = oldTransform || ''; }, 50);
            }
          }
        } catch(e) {}
        try {
          window.dispatchEvent(new Event('resize'));
        } catch(e) {}
      }
      window.wakeAndResumeVideo = wakeAndResumeVideo;

      // 2. Block dynamic <script src="..."> tags from known ad networks
      var adDomains = ['alwingulla', 'adsterra', 'monetag', 'propeller', 'exoclick', 'juicyads', 'hilltopads', 'popunder', 'syndication', 'highrevenuegate', 'profitcpm', 'disable-devtool', 'clickadilla', 'onclickads', 'popads', 'popcash', 'elina', 'fakecall'];
      try {
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
        if (h.includes('/pop') || h.includes('/ad') || h.includes('/clk') || h.includes('/out/') || h.includes('redirect') || h.includes('/promo') || h.includes('/click') || h.includes('adsterra') || h.includes('monetag')) {
          return false;
        }
        return h.includes('vidlink') || h.includes('vidsrc') || h.includes('vsembed') ||
               h.includes('2embed') || h.includes('autoembed') || h.includes('vidplay') ||
               h.includes('megacloud') || h.includes('embed.su') || h.includes('embedsu') ||
               h.includes('cloudorchestranova') || h.includes('orchestranova') ||
               h.includes('cloudnest') || h.includes('shadowland') || h.includes('vizcloud') ||
               h.includes('rabbitstream') || h.includes('movie-api') || h.includes('mcloud') ||
               h.includes('filemoon') || h.includes('streamtape') || h.includes('superstream') ||
               h.includes('google') || h.includes('cloudflare') || h.includes('smashystream') ||
               h.startsWith('/') || h.startsWith('#') || h === '';
      }

      // Hide common ad containers with CSS.
      function injectAdBlockStyles() {
        try {
          var vp = document.querySelector('meta[name="viewport"]');
          if (!vp) {
            vp = document.createElement('meta');
            vp.name = 'viewport';
            (document.head || document.documentElement).appendChild(vp);
          }
          vp.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
        } catch(e) {}

        try {
          if (document.getElementById('app-loader-override-style')) return;
          var style = document.createElement('style');
          style.id = 'app-loader-override-style';
          style.innerHTML = `
            html, body, #app, #root, div[id*="player"], div[class*="player"], div[class*="vidlink"] {
              width: 100% !important;
              height: 100% !important;
              margin: 0 !important;
              padding: 0 !important;
              overflow: hidden !important;
              background-color: #000 !important;
              -webkit-tap-highlight-color: transparent !important;
              box-sizing: border-box !important;
            }

            video, .vjs-tech, .jw-video, .plyr__video-wrapper {
              width: 100% !important;
              height: 100% !important;
              max-width: 100% !important;
              max-height: 100% !important;
              object-fit: contain !important;
            }

            div[id^="ad-"], div[id^="ad_"], div[id="ad"], div[id="ads"],
            div[class~="ad"], div[class~="ads"], div[class^="ad-"], div[class^="ad_"],
            .adsbygoogle,
            iframe[src*="doubleclick"], iframe[src*="adsterra"], iframe[src*="monetag"], iframe[src*="/ads/"],
            #pop, .popunder, .popup, #popup, div[class*="popunder"], div[class*="popup"],
            div[class*="fake-call"], div[class*="pop-call"], div[class*="elina"],
            div[class*="missed-call"], div[class*="avatar-popup"], div[class*="toast-call"],
            [id*="fake-call"], [id*="pop-call"], [id*="elina"], [class*="video-call"],
            a[target="_blank"] {
              display: none !important;
              visibility: hidden !important;
              opacity: 0 !important;
              pointer-events: none !important;
            }
          `;
          (document.head || document.documentElement).appendChild(style);
        } catch(e) {}
      }

      // Only SPECIFIC phrases here. Broad words like 'missed' or 'video call'
      // matched normal player text and caused endless remove/re-add loops.
      function isFakeCallText(text) {
        if (!text) return false;
        var t = text.toLowerCase();
        var phrases = [
          'missed video call', 'missed video calls',
          'join the video call', 'incoming call', 'has something to show',
          'live cam', 'wants to chat', 'private show'
        ];
        for (var i = 0; i < phrases.length; i++) {
          if (t.includes(phrases[i])) return true;
        }
        return false;
      }

      // Finds and removes fake video call / chat popup badges.
      // Only small elements are checked, and we use textContent (cheap).
      function removeFakeCallPopups() {
        try {
          if (!document.body) return;

          var elems = document.body.querySelectorAll('div, a, section, aside');
          for (var i = 0; i < elems.length; i++) {
            var el = elems[i];
            var txt = el.textContent || '';

            // Real fake-call badges have short text. Skip big containers.
            if (txt.length === 0 || txt.length > 200) continue;
            if (!isFakeCallText(txt)) continue;

            // Never touch anything that holds the video.
            if (el.querySelector('video')) continue;

            // Walk up a few levels to find the whole popup box.
            var topBox = el;
            var parent = el.parentElement;
            var levels = 0;
            while (parent && parent !== document.body && parent !== document.documentElement && levels < 4) {
              if (parent.querySelector('video') || parent.querySelector('iframe')) break;
              if ((parent.textContent || '').length > 300) break;
              topBox = parent;
              parent = parent.parentElement;
              levels++;
            }

            try { topBox.remove(); } catch(e) {
              topBox.style.setProperty('display', 'none', 'important');
            }
          }
        } catch(e) {}
      }

      function removeFloatingAdOverlays() {
        try {
          var elems = document.querySelectorAll('body > div, body > aside, body > section, a[target="_blank"]');
          for (var i = 0; i < elems.length; i++) {
            var el = elems[i];

            if (el.tagName === 'A' && el.getAttribute('target') === '_blank') {
              var href = (el.getAttribute('href') || '').toLowerCase();
              if (!isAllowedUrl(href)) {
                el.style.setProperty('display', 'none', 'important');
                el.style.setProperty('pointer-events', 'none', 'important');
                el.removeAttribute('target');
                el.setAttribute('href', 'javascript:void(0)');
              }
              continue;
            }

            // Protect the video player and its controls from being removed
            var hasMedia = el.querySelector('video, iframe, canvas');
            if (hasMedia) continue;

            var isControls = el.querySelector('button, input, [class*="control"], [class*="player"], [class*="vidlink"], [class*="vjs"], [class*="jw"], [class*="plyr"]');
            if (isControls) continue;

            var txt = (el.textContent || '').toLowerCase();
            if (txt.length > 300) continue;

            if (isFakeCallText(txt)) {
              try { el.remove(); } catch(e) {}
              continue;
            }

            var style = window.getComputedStyle ? window.getComputedStyle(el) : null;
            if (style) {
              var zIndex = parseInt(style.zIndex, 10);
              var pos = style.position;
              if ((pos === 'fixed' || pos === 'absolute') && (zIndex >= 10 || isNaN(zIndex))) {
                var containsAdLink = el.querySelector('a[target="_blank"]');
                var containsAdKeyword = adDomains.some(function(kw) { return txt.includes(kw); });
                if (containsAdLink || containsAdKeyword) {
                  try { el.remove(); } catch(e) {}
                }
              }
            }
          }
        } catch(e) {}
      }

      function purgeDomNode(node) {
        if (!node || !node.tagName) return;
        try {
          var tag = node.tagName.toUpperCase();

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
      }

      function purgeLoadersAndAds() {
        disablePopups();
        injectAdBlockStyles();
        removeFloatingAdOverlays();
        removeFakeCallPopups();

        try {
          var links = document.querySelectorAll('a[target="_blank"], iframe[src*="/ads/"], iframe[src*="adsterra"], iframe[src*="monetag"]');
          for (var i = 0; i < links.length; i++) {
            purgeDomNode(links[i]);
          }
        } catch(e) {}
      }

      window.purgeLoadersAndAds = purgeLoadersAndAds;

      // Capture phase listeners for clicks and touch events
      try {
        var eventsToBlock = ['click', 'touchstart', 'touchend', 'pointerdown', 'mousedown'];
        var handleInteraction = function(e) {
          disablePopups();
          var target = e.target;
          while (target && target !== document.body && target !== document.documentElement) {
            if (target.tagName === 'A') {
              var href = (target.getAttribute('href') || '').toLowerCase();
              var isTargetBlank = target.getAttribute('target') === '_blank';
              if (isTargetBlank || !isAllowedUrl(href)) {
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();
                if (target.getAttribute('target')) target.removeAttribute('target');
                if (href.startsWith('http')) target.setAttribute('href', 'javascript:void(0)');
                return false;
              }
            }
            target = target.parentElement;
          }
        };

        eventsToBlock.forEach(function(evt) {
          window.addEventListener(evt, handleInteraction, true);
        });
      } catch(e) {}

      // Override HTMLAnchorElement.prototype.click
      try {
        var originalClick = HTMLAnchorElement.prototype.click;
        HTMLAnchorElement.prototype.click = function() {
          var href = (this.getAttribute('href') || '').toLowerCase();
          var target = this.getAttribute('target');
          if (target === '_blank' || !isAllowedUrl(href)) {
            return;
          }
          return originalClick.apply(this, arguments);
        };
      } catch(e) {}

      injectAdBlockStyles();
      purgeLoadersAndAds();

      // Run cleaning (at most every 400ms) when the page changes
      var _purgeTimeout = null;
      function schedulePurge() {
        if (_purgeTimeout) return;
        _purgeTimeout = setTimeout(function() {
          _purgeTimeout = null;
          purgeLoadersAndAds();
        }, 400);
      }

      // Slower periodic scan (was every 500ms, now every 2 seconds)
      setInterval(purgeLoadersAndAds, 2000);

      try {
        var observer = new MutationObserver(function(mutations) {
          for (var i = 0; i < mutations.length; i++) {
            if (mutations[i].addedNodes && mutations[i].addedNodes.length > 0) {
              schedulePurge();
              break;
            }
          }
        });
        observer.observe(document.body || document.documentElement, { childList: true, subtree: true });
      } catch(e) {}
    })();
  """;

  // -------------------------------------------------------------------------
  // Setup / teardown
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _currentSeason = widget.season;
    _currentEpisode = widget.episode;
    _tvName = widget.seriesName;

    if (_isWindows) {
      windowManager.addListener(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _windowsFocusNode.requestFocus();
      });
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
    } else if (_isLinux) {
      // Linux has no in-app player, we show a "Watch in browser" button.
      isLoading = false;
    }
    // On Android / iOS there is nothing to set up here.
    // The InAppWebView widget creates itself in build().
  }

  @override
  void dispose() {
    if (_isWindows) {
      windowManager.removeListener(this);
    }
    _hideTimer?.cancel();
    _mobileSafetyTimer?.cancel();
    _windowsFocusNode.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Player URL + loading
  // -------------------------------------------------------------------------

  // CHANGED: the URL is now built from the server's "style" field.
  // (The old code checked the server NAME, e.g. contains('VidLink'), but the
  // names were changed to "Server 1/2/3", so those checks never matched.)
  void _updatePlayerUrl() {
    final server = kServerOptions[_selectedServerIndex];
    String url;

    if (server.style == 'query') {
      // Example: https://vidsrc.me/embed/movie?tmdb=123
      url = widget.isTv
          ? "${server.tvUrl}?tmdb=${widget.tmdbId}&season=$_currentSeason&episode=$_currentEpisode"
          : "${server.movieUrl}?tmdb=${widget.tmdbId}";
    } else if (server.style == 'vidlink') {
      // Example: https://vidlink.pro/movie/123?primaryColor=E8894D
      url = widget.isTv
          ? "${server.tvUrl}/${widget.tmdbId}/$_currentSeason/$_currentEpisode?primaryColor=E8894D"
          : "${server.movieUrl}/${widget.tmdbId}?primaryColor=E8894D";
    } else {
      // 'path' style. Example: https://vidsrc.to/embed/movie/123
      url = widget.isTv
          ? "${server.tvUrl}/${widget.tmdbId}/$_currentSeason/$_currentEpisode"
          : "${server.movieUrl}/${widget.tmdbId}";
    }

    setState(() {
      _playerUrl = url;
    });
  }

  // Reload the webview with the current _playerUrl.
  void _loadPlayerUrl() {
    _winController?.loadUrl(urlRequest: URLRequest(url: WebUri(_playerUrl)));
  }

  void _changeServer(int index) {
    if (index == _selectedServerIndex) return;
    setState(() {
      _selectedServerIndex = index;
      isLoading = true;
      _hasLoadedOnce = false;
    });
    _updatePlayerUrl();
    _loadPlayerUrl();
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
    _loadPlayerUrl();
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
    _loadPlayerUrl();
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

  // -------------------------------------------------------------------------
  // Ad blocking helpers
  // -------------------------------------------------------------------------

  // True if the URL looks like an ad or popup.
  bool _looksLikeAd(String url) {
    final lower = url.toLowerCase();

    if (kAdNetworkKeywords.any((word) => lower.contains(word))) return true;
    if (kAdUrlPaths.any((path) => lower.contains(path))) return true;

    // Special case: popups coming from vidsrc
    if (lower.contains("vidsrc") &&
        (lower.contains("/pop") || lower.contains("/out/") || lower.contains("/ad"))) {
      return true;
    }
    return false;
  }

  // Decides if a URL is allowed to load.
  // [isMainFrame] is true for the top page, false for iframes.
  bool _shouldAllowUrl(String url, {required bool isMainFrame}) {
    final lower = url.toLowerCase();

    // Empty iframes are fine
    if (lower.startsWith("about:blank")) return true;

    // 1. Block anything that looks like an ad
    if (_looksLikeAd(lower)) {
      debugPrint("Blocking ad URL: $lower");
      return false;
    }

    final playerHost = Uri.tryParse(_playerUrl)?.host.toLowerCase();

    // 2. After the player has loaded, the main page must not jump to another site
    if (isMainFrame && _hasLoadedOnce) {
      final requestHost = Uri.tryParse(lower)?.host.toLowerCase();
      if (playerHost != null &&
          requestHost != null &&
          playerHost != requestHost &&
          !lower.contains(widget.tmdbId.toString())) {
        debugPrint("Blocking post-load redirect to: $lower");
        return false;
      }
    }

    // 3. Only allow known video domains (or the current player's own host)
    final isAllowedDomain = kAllowedDomains.any((domain) => lower.contains(domain)) ||
        (playerHost != null && playerHost.isNotEmpty && lower.contains(playerHost));

    if (isAllowedDomain || lower == _playerUrl.toLowerCase()) {
      return true;
    }

    debugPrint("Blocking navigation to: $lower");
    return false;
  }

  // CHANGED: moved out of the widget so we can turn it off on Windows.
  // Blocks ad files before they download (Android only).
  // Windows and iOS do not support this callback.
  Future<WebResourceResponse?> _interceptRequest(
      InAppWebViewController controller,
      WebResourceRequest request,
      ) async {
    final url = request.url.toString().toLowerCase();

    if (kAdNetworkKeywords.any((word) => url.contains(word))) {
      debugPrint("Intercepted and blocked ad resource: $url");
      return WebResourceResponse(
        contentType: 'text/javascript',
        data: Uint8List(0),
      );
    }

    return null;
  }

  // -------------------------------------------------------------------------
  // Windows only: pause / play when the window is minimized / restored
  // -------------------------------------------------------------------------

  @override
  void onWindowMinimize() {
    if (mounted && _isWindows) {
      setState(() {
        _isMinimized = true;
      });
      _winController?.pause();
      _winController?.evaluateJavascript(source: """
        (function() {
          function pauseAll(w) {
            try {
              var vids = w.document.querySelectorAll('video, audio');
              for (var i = 0; i < vids.length; i++) vids[i].pause();
            } catch(e) {}
            try {
              for (var i = 0; i < w.frames.length; i++) pauseAll(w.frames[i]);
            } catch(e) {}
          }
          pauseAll(window);
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
      _winController?.resume();
      _winController?.evaluateJavascript(source: """
        (function() {
          function playAll(w) {
            try {
              var vids = w.document.querySelectorAll('video, audio');
              for (var i = 0; i < vids.length; i++) {
                if (vids[i].paused && vids[i].currentTime > 0) vids[i].play().catch(function(){});
              }
            } catch(e) {}
            try {
              for (var i = 0; i < w.frames.length; i++) playAll(w.frames[i]);
            } catch(e) {}
          }
          playAll(window);
        })();
      """);
      _triggerWebViewResize();
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

  void _triggerWebViewResize() {
    if (!_isWindows || _winController == null) return;
    const jsWakeup = """
      (function() {
        try {
          if (typeof window.wakeAndResumeVideo === 'function') {
            window.wakeAndResumeVideo();
          } else {
            window.dispatchEvent(new Event('resize'));
            var vids = document.getElementsByTagName('video');
            for (var i = 0; i < vids.length; i++) {
              if (vids[i].paused && vids[i].currentTime > 0) vids[i].play();
            }
          }
        } catch(e) {}
      })();
    """;
    _winController?.evaluateJavascript(source: jsWakeup);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _winController?.evaluateJavascript(source: jsWakeup);
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _winController?.evaluateJavascript(source: jsWakeup);
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _winController?.evaluateJavascript(source: jsWakeup);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _winController?.evaluateJavascript(source: jsWakeup);
    });
  }

  Future<void> _toggleWindowsFullScreen() async {
    bool nowFull = await windowManager.isFullScreen();
    final bool newFullState = !nowFull;
    await windowManager.setFullScreen(newFullState);
    if (mounted) {
      setState(() {
        _isFullScreen = newFullState;
        if (_isFullScreen) {
          _startHideTimer();
        } else {
          _showControls = true;
        }
      });
      _triggerWebViewResize();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _windowsFocusNode.requestFocus();
      });
    }
  }

  Future<void> _exitWindowsFullScreen() async {
    if (_isWindows && _isFullScreen) {
      await windowManager.setFullScreen(false);
      if (mounted) {
        setState(() {
          _isFullScreen = false;
          _showControls = true;
        });
        _triggerWebViewResize();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _windowsFocusNode.requestFocus();
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
    if (_isMinimized) return;
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    if (_isFullScreen) {
      _startHideTimer();
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

  // -------------------------------------------------------------------------
  // Bottom sheets
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // UI pieces
  // -------------------------------------------------------------------------

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

  // The black "Loading stream..." screen shown on top of the webview.
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: loadingProgress > 0 ? loadingProgress : null,
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
    );
  }

  // The ONE webview used on Windows, Android and iOS.
  Widget _buildInAppWebView() {
    return InAppWebView(
      key: const ValueKey("win_movie_player_webview"),
      // Only Windows has an environment. On mobile this is null, which is fine.
      webViewEnvironment: _webViewEnvironment,
      initialUrlRequest: URLRequest(url: WebUri(_playerUrl)),

      // Inject the cleanup script into the page AND every iframe.
      // CHANGED: it can be switched off with kEnableCleanupScript (top of file).
      initialUserScripts: UnmodifiableListView(
        kEnableCleanupScript
            ? [
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
        ]
            : <UserScript>[],
      ),

      initialSettings: InAppWebViewSettings(
        userAgent: _userAgent,
        preferredContentMode: UserPreferredContentMode.MOBILE,
        useWideViewPort: false,
        loadWithOverviewMode: false,
        transparentBackground: false,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        hardwareAcceleration: true,
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: false,
        supportMultipleWindows: false,
        isInspectable: kDebugMode,
      ),

      onWebViewCreated: (controller) {
        _winController = controller;
      },

      onProgressChanged: (controller, progress) {
        if (!mounted) return;
        setState(() {
          loadingProgress = progress / 100;
          if (progress > 35) {
            isLoading = false;
            _hasLoadedOnce = true;
            _mobileSafetyTimer?.cancel();
          }
        });
      },

      onLoadStart: (controller, url) {
        if (!mounted) return;
        if (!_hasLoadedOnce) {
          setState(() => isLoading = true);
        }
        // Safety net: never keep the loading screen for more than 3 seconds
        _mobileSafetyTimer?.cancel();
        _mobileSafetyTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && isLoading) {
            setState(() => isLoading = false);
          }
        });
        // CHANGED: we no longer call evaluateJavascript(_cleanupScript) here.
        // The UserScripts above already inject it into every page and iframe.
      },

      onLoadStop: (controller, url) async {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          _hasLoadedOnce = true;
        });
        _mobileSafetyTimer?.cancel();
        // CHANGED: removed the extra cleanup script injection here too.
        await controller.evaluateJavascript(source: "document.body.style.backgroundColor = 'black';");
      },

      onReceivedError: (controller, request, error) {
        debugPrint("WebView Load Error: ${error.description} (code: ${error.type}) at ${request.url}");
      },

      onReceivedHttpError: (controller, request, errorResponse) {
        debugPrint("WebView HTTP Error: ${errorResponse.reasonPhrase} (status: ${errorResponse.statusCode}) at ${request.url}");
      },

      // Block every popup window (target=_blank, window.open)
      onCreateWindow: (controller, createWindowAction) async {
        return false;
      },

      // CHANGED: JS dialogs (alert/confirm/prompt) are answered right away,
      // so the native side never sits waiting for a dialog nobody can see.
      onJsAlert: (controller, jsAlertRequest) async {
        return JsAlertResponse(handledByClient: true);
      },
      onJsConfirm: (controller, jsConfirmRequest) async {
        return JsConfirmResponse(handledByClient: true);
      },
      onJsPrompt: (controller, jsPromptRequest) async {
        return JsPromptResponse(handledByClient: true);
      },

      // CHANGED: only used on Android. On Windows it is turned off (null),
      // so we do not run Dart code for every single network request.
      shouldInterceptRequest: _isWindows ? null : _interceptRequest,

      // Decide if the page may navigate to a new URL
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final uri = navigationAction.request.url;
        if (uri == null) return NavigationActionPolicy.CANCEL;

        final allowed = _shouldAllowUrl(
          uri.toString(),
          isMainFrame: navigationAction.isForMainFrame,
        );

        return allowed ? NavigationActionPolicy.ALLOW : NavigationActionPolicy.CANCEL;
      },
    );
  }

  // -------------------------------------------------------------------------
  // build()
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLinux) {
      body = _buildBrowserFallback("Playback opens in your browser on Linux.");
    } else if (_isWindows) {
      // ---------- Windows ----------
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
              _buildInAppWebView(),
              if (isLoading && !_hasLoadedOnce) _buildLoadingOverlay(),
              // Floating exit button for Full Screen
              if (_isFullScreen && _showControls)
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
    } else {
      // ---------- Android / iOS ----------
      body = Stack(
        children: [
          // Tapping the video shows / hides our controls
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
            child: _buildInAppWebView(),
          ),
          if (isLoading && !_hasLoadedOnce) _buildLoadingOverlay(),
          _buildMobileControls(),
        ],
      );
    }

    // On phones we draw our own controls on top of the video, so no AppBar.
    final bool useMobileOverlay = !_isWindows && !_isLinux;
    final bool hideAppBar = _isFullScreen || useMobileOverlay;

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
              onPressed: _showInfo,
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
        focusNode: _windowsFocusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            if (_isFullScreen) {
              _exitWindowsFullScreen();
            }
          }
        },
        child: playerScaffold,
      );
    }

    return playerScaffold;
  }
}
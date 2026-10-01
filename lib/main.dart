import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:movie_explorer/authentication/login.dart';
import 'package:movie_explorer/authentication/register.dart';
import 'package:movie_explorer/authentication/forgot_password.dart';
import 'package:movie_explorer/authentication/profile.dart';
import 'package:movie_explorer/subscription/subscription_screen.dart';
import 'package:movie_explorer/appUI/favorites/favorites.dart';
import 'package:movie_explorer/appUI/home/home.dart';
import 'package:movie_explorer/appUI/movies/movies_screen.dart';
import 'package:movie_explorer/appUI/tv_shows/tv_shows_screen.dart';
import 'package:movie_explorer/appUI/search/search.dart';
import 'package:movie_explorer/theme/app_theme.dart';
import 'package:movie_explorer/reusable/subscription_gate.dart';

// Global webview environment to prevent re-initialization freezes
WebViewEnvironment? globalWebViewEnvironment;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize for Desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    if (Platform.isWindows) {
      // 1. Set a minimum size to prevent 0x0 rendering freezes
      await windowManager.setMinimumSize(const Size(400, 300));

      // 2. Initialize WebView2 environment early with a safe path
      try {
        final dir = await getApplicationSupportDirectory();
        final userDataFolder = '${dir.path}\\webview_data';
        await Directory(userDataFolder).create(recursive: true);
        
        globalWebViewEnvironment = await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(userDataFolder: userDataFolder),
        );
      } catch (e) {
        debugPrint("Failed to init WebView environment: $e");
      }
    }

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const myApp());
}

class myApp extends StatelessWidget {
  const myApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Explorer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: LoginScreen.id,
      routes: {
        LoginScreen.id: (context) => const LoginScreen(),
        RegisterScreen.id: (context) => const RegisterScreen(),
        ForgotPasswordScreen.id: (context) => const ForgotPasswordScreen(),
        ProfileScreen.id: (context) => const ProfileScreen(),
        SubscriptionScreen.id: (context) => const SubscriptionScreen(),
        HomeScreen.id: (context) => const SubscriptionGate(child: HomeScreen()),
        MoviesScreen.id: (context) => const SubscriptionGate(child: MoviesScreen()),
        TVShowsScreen.id: (context) => const SubscriptionGate(child: TVShowsScreen()),
        FavoritesScreen.id: (context) => const SubscriptionGate(child: FavoritesScreen()),
        SearchScreen.id: (context) => const SubscriptionGate(child: SearchScreen()),
      },
    );
  }
}

# 🎬 Movie Explorer

Movie Explorer is a sleek and modern Flutter application designed for movie enthusiasts to discover, search, and watch their favorite movies and TV series. It leverages real-time data from The Movie Database (TMDB) and features a cinematic UI with integrated video players.

## 🚀 Features

-   **Dynamic Home Screen**: Categorized sections including Trending, Popular, Now Playing, Action, Sci-Fi, Horror, Kids, and more.
-   **Cinematic Movie Details**: Beautiful backdrop images, genre tags, ratings, and detailed overviews.
-   **Integrated Movie Player**: Watch full movies and TV series directly in the app via an embedded third-party player (`vidsrc`).
-   **Trailer Playback**: High-quality YouTube trailers integrated for every movie.
-   **Smart Search**: Quickly find any movie or TV show from the TMDB database.
-   **Favorites System**: Save your "Must Watch" movies to a personal list (stored locally using `shared_preferences`).
-   **Premium UI/UX**:
    *   **Skeleton Loading**: Smooth shimmering effects instead of standard spinners.
    *   **Auto-Rotation**: Manual and automatic landscape support for an immersive viewing experience.
    *   **Custom Launcher Icon**: Unique movie-themed app icon.
-   **Cross-Platform**: Fully compatible with Android, iOS, and Windows desktop.

## 🛠 Tech Stack

-   **Frontend**: [Flutter](https://flutter.dev/) (Dart)
-   **API**: [The Movie Database (TMDB) API](https://www.themoviedb.org/documentation/api)
-   **Video Playback**: 
    *   `webview_flutter` (Full Movie Player)
    *   `youtube_player_flutter` (Trailers)
-   **Storage**: `shared_preferences` (Favorites)
-   **Assets**: Custom icons and urban-themed background images.

## 📥 Getting Started

### Prerequisites

-   [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
-   An Android Emulator, iOS Simulator, or physical device.
-   **Android Requirement**: Min SDK 21 (Android 5.0) is required for the Movie Player.

### Installation & Setup

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/your-username/Movie-explorer-main.git
    cd Movie-explorer-main
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Generate Launcher Icons**:
    ```bash
    flutter pub run flutter_launcher_icons:main
    ```

4.  **Run the app**:
    ```bash
    flutter run
    ```

## 📂 Project Structure

```text
lib/
├── appUI/
│   ├── favorites/      # Favorites list screen
│   ├── footer/         # Bottom nav bar (phone layout)
│   ├── shell/          # Adaptive scaffold (NavigationRail on desktop)
│   ├── home/           # Home, Details, and Player screens
│   ├── search/         # Search functionality
│   ├── services/       # TMDB API and Favorite logic
│   └── widget/         # Reusable widgets (MovieCard, Skeleton, etc.)
├── authentication/     # Login and Register screens
├── reusable/           # Custom UI components (TextFields, Buttons, responsive helpers)
└── main.dart           # App entry point and theme configuration
```

## 🖥️ Windows Desktop

The app runs natively on Windows via `flutter run -d windows`. On a window
wider than ~1024px it switches from the phone's bottom nav bar to a premium
top nav bar, and grids/rails widen to use the extra space.

Movie/TV playback and trailers play **in-app** on Windows via
[`flutter_inappwebview`](https://pub.dev/packages/flutter_inappwebview), which wraps
Microsoft Edge WebView2 (a real, modern Chromium engine) — this is separate
from `webview_flutter`/`youtube_player_flutter`, which only support
mobile. Windows 10/11 ship with the WebView2 Runtime pre-installed in the
vast majority of cases; if it's somehow missing, playback falls back to a
"Watch in browser" button instead of crashing.

Linux has no equivalent maintained package yet, so playback there still
opens in the system browser — everything else (search, favorites,
browsing) works the same as on mobile.

### If the Windows build fails with a `<experimental/coroutine>` / C2338 error or a Path/MSB3491 error

1. **Coroutine Error**: If you see `error C2338: ... <experimental/coroutine> ... are deprecated`, this project's `windows/CMakeLists.txt` already includes the workaround. Just run `flutter clean` and rebuild.

2. **Path Length Error (MSB3491)**: If you see `error MSB3491: Could not write lines to file ... Could not find a part of the path`, it means the build path is too long for Windows (260 character limit).
   * **Fix**: Move the project folder to a shorter path (e.g., `C:\src\movie_explorer`) or enable "Long Paths" in the Windows Registry (`LongPathsEnabled = 1`).

3. **WebView2 Runtime**: If the app runs but movies don't play (showing "Couldn't start the in-app player"), ensure you have the [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/) installed.

Always perform a clean rebuild after fixing these environment issues:
```bash
flutter clean
flutter pub get
flutter run -d windows
```

### Packaging an installer (.msix) to share with other laptops

A raw `flutter build windows` produces a folder you'd have to zip and share
manually. For a real double-click installer with a Start Menu entry and an
uninstaller, this project is set up to package an `.msix` instead:

```bash
flutter build windows --release
dart run msix:create
```

This produces:
```
build\windows\x64\runner\Release\movie_explorer.msix
```

No signing certificate is configured in `pubspec.yaml`, so `msix:create`
automatically generates a free self-signed **test certificate** the first
time you run it (saved as `movie_explorer_TemporaryKey.pfx` in the project
root). Because it isn't a certificate from a trusted authority, anyone
installing the `.msix` on a **different** laptop needs to trust that same
certificate once before Windows will allow the install:

1. Copy both the `.msix` file and the `.pfx` certificate file to the other
   laptop.
2. Double-click the `.pfx` → **Install Certificate** → **Local Machine** →
   place it in the **Trusted People** store (you'll need admin rights).
3. Double-click the `.msix` and click **Install**.

From then on, `Movie Explorer` shows up in the Start Menu and Windows
"Apps & features" like any normally-installed app, and can be uninstalled
the same way.

If you'd rather not deal with certificates at all, publishing through the
Microsoft Store (or getting a proper code-signing certificate) removes this
step — but that's a bigger undertaking than a personal/portfolio build
usually needs.

## ⚠️ Notes

-   **Movie Player**: The embedded player uses `vidsrc.to`. It includes ad-blocking logic to provide a cleaner experience, but some external links might still be blocked by the app's security settings.
-   **API Key**: The project currently uses a default TMDB API key. For production, please replace it with your own key in `lib/appUI/services/tmdb_service.dart`.

## 📄 License

This project is open-source and available under the MIT License.

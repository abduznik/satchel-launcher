# Project Indie

A portable, offline-first DRM-free game launcher designed to live on a USB drive. Drop your Windows games into the `Games/` folder, and Project Indie handles the rest — metadata, cover art, save synchronization, and launching.

## What Is This?

Project Indie is a game library manager that runs entirely from a portable drive. It's built for people who carry their games on a USB stick and want a clean, unified way to browse and launch them on any Windows PC — no installation, no DRM, no launcher bloat.

Plug in your drive, and Indie auto-starts with a splash screen, scans for games, fetches metadata and cover art from online databases, and lets you launch directly into your library.

## Features

### Game Library
- Drop game folders into `Games/` — each folder should contain the game's `.exe`
- Auto-detects the main executable via token-scoring against the folder name
- Fetches metadata (title, genre, release date, rating, developer) and cover art from:
  - **IGDB** — game info, genres, release dates, screenshots, trailers
  - **SteamGridDB** — high-quality grid art and covers
  - **ScreenScraper** — box art and screenshots
- All metadata and art is cached locally in each game's `.indie/` folder for offline use
- Grid view with hover effects and list+detail view with full banners

### Save Synchronization (OmniSave)
Every game automatically uses [OmniSave](https://github.com/abduznik/OmniSave) for save file management:
- Before launching, saves are synced from the portable drive to the local system path
- After closing the game, saves are synced back to the drive
- This means your saves follow you between machines — no manual copying
- OmniSave is bundled in `thirdparty/` and copied to each game's `.indie/` directory at launch

### Save Location Detection (PCGamingWiki)
Project Indie automatically detects where games store their saves:
- Searches PCGamingWiki for save file information
- Expands environment variables (`%APPDATA%`, `~/`, etc.)
- Shows detected save locations in the game detail view
- Falls back to default paths if detection fails

### Auto-Start
On Windows, an `AutoRun.inf` file triggers Project Indie to launch when the drive is mounted. You can also launch it manually from the drive root.

### Themes
6 built-in theme presets:
- **Default Dark** — Deep purple accents
- **Light** — Clean light theme
- **Crimson** — Red accents
- **Rose Gold** — Pink accents
- **Neon Cyan** — Cyan accents
- **OLED Black** — Pure black for OLED displays

### Controller Support
- Full SDL2 gamepad stack with known controller mappings
- D-pad navigation, deadzone configuration, axis state machine
- Button hints bar and automatic input mode detection
- Focus effects with visual feedback

### Setup Wizard
First-run wizard that guides you through:
1. Drive detection
2. Games and saves path configuration
3. API key setup (SteamGridDB, IGDB, ScreenScraper)
4. AutoStart.inf generation

## Drive Structure

```
DriveRoot/
├── AutoRun.inf               # Windows auto-start
├── ProjectIndie/             # This app
│   ├── indie_launcher.exe
│   └── thirdparty/
│       └── OmniSave.exe      # Bundled copy
├── Games/                    # Drop game folders here
│   ├── GameName/
│   │   ├── game.exe
│   │   └── .indie/           # Cached metadata, art & OmniSave
│   └── ...
├── Saves/                    # OmniSave backup saves
└── Config/                   # App settings & encrypted API keys
```

## API Keys (Optional)

Project Indie can fetch richer metadata if you provide API keys:
- **SteamGridDB** — Free, get a key at [steamgriddb.com/profile/preferences](https://www.steamgriddb.com/profile/preferences)
- **IGDB** — Free via Twitch, requires Twitch developer account
- **ScreenScraper** — Free tier available, paid tiers for higher rate limits

Without API keys, you can still use the launcher — you'll be prompted to manually enter game titles and can skip metadata fetching. All keys are stored encrypted on the drive.

## Tech Stack

- **Flutter** — Cross-platform UI framework
- **Dart** — Application language
- **Riverpod** — State management
- **Hive** — Local storage
- **Dio** — HTTP client for API calls
- **Material 3** — Design system with theme presets

## Building

```bash
# Ensure Flutter is installed
flutter pub get
flutter build windows
```

The built executable will be in `build/windows/x64/runner/Release/`.

## License

MIT

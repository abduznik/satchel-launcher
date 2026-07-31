# Project Indie

A portable, offline-first DRM-free game launcher designed to live on a USB drive. Drop your Windows games into the `Games/` folder, and Project Indie handles the rest — metadata, cover art, save synchronization, and launching.

## What Is This?

Project Indie is a game library manager that runs entirely from a portable drive. It's built for people who carry their games on a USB stick and want a clean, unified way to browse and launch them on any Windows PC — no installation, no DRM, no launcher bloat.

Plug in your drive, and Indie auto-starts with a splash screen, scans for games, fetches metadata and cover art from online databases, and lets you launch directly into your library.

## Current Status

**Phase 1 — Windows Native**
- Windows native games (`.exe`)
- Portable by design — everything lives on the drive
- OmniSave integration for automatic save file sync across machines
- PCGamingWiki integration for automatic save location detection
- 6 theme presets with Material 3 design
- Full controller and keyboard navigation support

**Future Plans**
- Proton/Wine auto-detection for Linux games (OmniSave already supports this via CrossOver/Proton)
- Steam/Proton prefix management
- Cloud save sync via OmniSave

## Features

### Game Library
1. Drop game folders into `Games/` — each folder should contain the game's `.exe`
2. Project Indie scans `Games/` on startup
3. For each game, it fetches metadata (title, genre, release date) and cover art from:
   - **SteamGridDB** — high-quality grid art and covers
   - **IGDB** — game info, genres, release dates
   - **ScreenScraper** — box art and screenshots
4. All metadata and art is cached locally in each game's `.indie/` folder for offline use

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
- Full gamepad navigation with D-pad support
- Button hints bar (A=Select, B=Back, Y=Details, X=Favorite)
- Automatic input mode detection (mouse/keyboard/gamepad)
- Focus effects with visual feedback

### Setup Wizard
First-run wizard that guides you through:
1. Drive detection
2. Games and saves path configuration
3. API key setup (SteamGridDB, IGDB, ScreenScraper)
4. AutoStart.inf generation

## Drive Structure

```
H:\ (Indie Lib)
├── OmniSave.exe              # Save sync tool
├── AutoRun.inf               # Windows auto-start
├── ProjectIndie\             # This app
│   ├── indie_launcher.exe
│   └── thirdparty\
│       └── OmniSave.exe      # Bundled copy
├── Games\                    # Drop game folders here
│   ├── GameName\
│   │   ├── game.exe
│   │   └── .indie\           # Cached metadata, art & OmniSave
│   └── ...
├── Saves\                    # OmniSave backup saves
└── Config\                   # App settings & encrypted API keys
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

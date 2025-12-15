# GameKeepr Flutter App - Context

## Project Overview
GameKeepr is a Flutter mobile application for managing board game collections with NFC tag support, BoardGameGeek (BGG) integration, and physical shelf location tracking. The app is iOS-focused and uses Material Design.

**Created by**: Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)

## Core Features
- **BGG Integration**: Sync collection, play history, and ownership status via BGG API v2 (XML) and REST API
- **NFC Support**: Write/read game and shelf location tags using NFC chips
- **Physical Tracking**: Shelf/bay location system (e.g., A1-H8 grid)
- **Game Recognition**: Experimental OCR-based game identification from shelf photos using Google ML Kit
- **Play Tracking**: Record plays with win/loss tracking, sync from BGG
- **Loan Management**: Track loaned games with borrower and return dates
- **Game Scheduling**: Schedule future game sessions with sharing capabilities
- **Tagging System**: Custom tags for organizing games
- **Wishlist & Save for Later**: Track games you want to own (wishlist) or consider for later (saved for later)
- **Search & Filter**: Multi-view (Collection, All Games, Recently Played, Wishlist, Saved for Later, Scheduled)
- **Data Management**: Export/restore backups, offline-first with SQLite

## Technology Stack
- **Framework**: Flutter SDK 3.0.0+
- **Language**: Dart
- **State Management**: Riverpod (flutter_riverpod ^2.4.9)
- **Database**: SQLite (sqflite ^2.3.0)
- **HTTP Client**: Dio ^5.4.0 with cookie management
- **NFC**: nfc_manager ^3.3.0
- **ML/OCR**: google_mlkit_text_recognition ^0.13.0
- **Image Handling**: cached_network_image, image_picker, camera
- **Text Matching**: string_similarity ^2.0.0
- **Others**: shared_preferences, intl, share_plus, file_picker, flutter_secure_storage

## Project Structure
```
lib/
├── main.dart                 # App entry point with Material theme
├── constants/                # App-wide constants (location grid, etc.)
├── features/                 # Feature modules (currently: social)
│   └── social/
│       └── widgets/
├── models/                   # Data models
│   ├── game.dart             # Core game model
│   ├── play.dart             # Play tracking model
│   ├── game_loan.dart        # Loan tracking model
│   ├── scheduled_game.dart   # Scheduled sessions model
│   ├── game_match_result.dart # OCR matching results
│   ├── game_with_play_info.dart
│   └── game_with_loan_info.dart
├── providers/                # Riverpod providers and state management
│   └── app_providers.dart
├── screens/                  # UI screens (17 screens)
│   ├── home_screen.dart
│   ├── game_details_screen.dart
│   ├── settings_screen.dart
│   ├── nfc_scan_screen.dart
│   ├── nfc_record_play_screen.dart
│   ├── nfc_loan_game_screen.dart
│   ├── write_shelf_tag_screen.dart
│   ├── shelf_view_screen.dart
│   ├── move_games_screen.dart
│   ├── bgg_search_screen.dart
│   ├── wishlist_screen.dart
│   ├── saved_for_later_screen.dart
│   ├── scheduled_games_screen.dart
│   ├── active_loans_screen.dart
│   ├── manage_tags_screen.dart
│   ├── game_recognition_screen.dart
│   └── game_recognition_results_screen.dart
├── services/                 # Business logic layer
│   ├── database_service.dart          # SQLite operations
│   ├── bgg_service.dart               # BGG API integration
│   ├── nfc_service.dart               # NFC read/write operations
│   ├── text_recognition_service.dart  # Google ML Kit OCR
│   └── game_matching_service.dart     # Fuzzy matching for OCR results
└── widgets/                  # Reusable UI components
    ├── location_picker.dart
    ├── game_tags_widget.dart
    ├── loan_game_dialog.dart
    └── filter_bottom_sheet.dart
```

## Architecture Patterns
- **State Management**: Riverpod providers for app-wide state
- **Database Layer**: DatabaseService handles all SQLite CRUD operations
- **API Layer**: BggService manages all BGG API calls (XML parsing, REST auth)
- **NFC Layer**: NfcService abstracts NFC read/write operations
- **Offline-First**: Local SQLite database with periodic BGG sync
- **Material Design**: Material 3 with custom theme (seedColor: blue)

## Development Commands
```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# iOS pod install (if needed)
cd ios && pod install && cd ..

# Build
flutter build ios

# Run tests
flutter test

# Code generation (Riverpod)
flutter pub run build_runner build
```

## Key Conventions
- **Models**: Dart classes/records in `lib/models/`
- **Screen naming**: `*_screen.dart` for all screens
- **Service naming**: `*_service.dart` for all services
- **Async operations**: Use async/await with proper error handling
- **Navigation**: Direct MaterialPageRoute navigation (no named routes)
- **Theme**: Centralized in main.dart, Material 3, blue color scheme
- **NFC tags**: Store game IDs or shelf locations as simple strings

## BGG API Integration
- **Collection sync**: `/xmlapi2/collection` (XML API v2)
- **Game details**: `/xmlapi2/thing` (with stats, comments expansion)
- **Play history**: `/xmlapi2/plays`
- **Authentication**: `/login/api/v1` (REST API, cookie-based)
- **Ownership updates**: `/api/collectionitems` (REST API, requires auth)
- **Rate limiting**: BGG API has rate limits; handle 429 responses

## NFC Implementation
- **Game tags**: Write BGG game ID to NFC tag
- **Shelf tags**: Write shelf location string (e.g., "A1")
- **Read modes**: Scan tag to open game details or record play/loan
- **Requirements**: iPhone 7+ for NFC hardware
- **Permissions**: NFCReaderUsageDescription in Info.plist

## Database Schema (SQLite)
- **Current version**: 13
- **Tables**: `games`, `plays`, `scheduled_games`, `game_loans`, `game_tags`
- **Game fields**: includes `owned`, `wishlisted`, `saved_for_later`, `has_nfc_tag` boolean flags (stored as INTEGER 0/1)
- **Migrations**: Automatic schema upgrades handled in database_service.dart

## Testing & Debugging
- **iOS target**: iOS 13.0+
- **NFC testing**: Requires physical iPhone 7+ (simulator doesn't support NFC)
- **BGG sandbox**: Use test accounts for development
- **Image caching**: cached_network_image handles caching automatically

## Common Tasks
- **Add new screen**: Create in `lib/screens/`, update navigation from relevant screen
- **Add new model**: Create in `lib/models/`, update DatabaseService if persistence needed
- **Add new service**: Create in `lib/services/`, inject via Riverpod provider
- **Modify theme**: Update ThemeData in main.dart
- **Add BGG API endpoint**: Extend BggService with new methods

## Important Notes
- App was entirely written by Claude AI
- Use `fvm flutter` commands if Flutter Version Management is configured
- NFC operations must be on physical device
- Game recognition is experimental (accuracy varies)
- BGG sync can be slow for large collections
- Always test NFC functionality on real hardware

## Files to Reference
- `README.md` - Comprehensive feature documentation and user guide
- `pubspec.yaml` - Dependencies and app metadata
- `lib/main.dart` - App initialization and theme
- `lib/services/database_service.dart` - Database schema and operations
- `lib/services/bgg_service.dart` - BGG API integration details
- `lib/services/nfc_service.dart` - NFC implementation patterns

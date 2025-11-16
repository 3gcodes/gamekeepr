# Game Keepr

A mobile Flutter application for tracking your board game collection with NFC support.

## Features

- **BGG Integration**: Sync your board game collection from BoardGameGeek
- **Local Storage**: SQLite database for offline access to your collection
- **NFC Support**: Write game IDs to NFC tags and scan tags to view game details
- **Location Tracking**: Track where each game is stored (custom text field)
- **Search**: Search through your collection by game name
- **Game Details**: View detailed information including:
  - Game images
  - Year published
  - Player count
  - Playtime
  - BGG rating
  - Description
  - Custom location

## Setup

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- iOS device with NFC capability (iPhone 7 or newer)
- Xcode for iOS development
- BoardGameGeek account

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. For iOS, ensure you have the proper entitlements:
   - NFC Tag Reading capability must be enabled in Xcode
   - Info.plist already includes NFC configuration

4. Run the app:
   ```bash
   flutter run
   ```

## Usage

### Initial Setup

1. Open the app and navigate to Settings (gear icon)
2. Enter your BoardGameGeek username
3. Tap "Save Username"
4. Return to the home screen and tap the sync button (circular arrows)
5. Wait for your collection to sync (this may take a few minutes for large collections)

### Viewing Games

- Browse your collection on the home screen
- Use the search bar to find specific games
- Tap any game to view detailed information

### Managing Locations

1. Tap on a game to open its details
2. Enter a location in the "Location" field (e.g., "Shelf B, Bay 8")
3. Tap "Save Location"
4. The location will appear in the game list

### Using NFC

#### Writing to NFC Tags

1. Open a game's details screen
2. Tap the NFC icon in the app bar
3. Hold your phone near an NFC tag
4. Wait for confirmation that the write was successful

#### Reading NFC Tags

1. From the home screen, tap the NFC icon
2. Hold your phone near a tagged game box
3. The app will automatically open that game's details screen

### Syncing

- Tap the sync button on the home screen to update your collection
- The sync will:
  - Add new games from your BGG collection
  - Update existing game information
  - Preserve your custom location data

## Technical Details

### Architecture

- **State Management**: RiverPod
- **Local Database**: SQLite (via sqflite)
- **HTTP Client**: http package for BGG API calls
- **NFC**: nfc_manager package
- **Image Caching**: cached_network_image

### Data Storage

- Games are stored in a local SQLite database
- BGG username is stored in SharedPreferences
- Images are cached for offline viewing (hybrid mode)

### BGG API

The app uses BoardGameGeek's XML API v2 to fetch collection data:
- Collection endpoint: `/xmlapi2/collection`
- Thing endpoint: `/xmlapi2/thing` for detailed game information

## Requirements

- iOS 13.0 or higher (for NFC support)
- iPhone 7 or newer (for NFC hardware)
- Internet connection for syncing (offline browsing supported)

## Troubleshooting

### NFC Not Working

- Ensure your device supports NFC (iPhone 7 or newer)
- Check that NFC is enabled in device settings
- Make sure the app has necessary permissions in iOS Settings

### Sync Failing

- Verify your BGG username is correct
- Check your internet connection
- BGG API may be slow - try again after a few minutes
- Large collections may take several minutes to sync

### Games Not Showing

- Ensure you've synced at least once
- Check that your BGG collection is set to "own" the games
- Try clearing data and re-syncing (Settings > Clear All Data)

## License

This project is provided as-is for personal use.

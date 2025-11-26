# Game Keepr

A mobile Flutter application for managing your board game collection with NFC tag support, BoardGameGeek integration, and shelf location tracking.

## About This Project

This application was entirely written by **Claude** (Anthropic's AI assistant), specifically using **Claude Sonnet 4.5** (model: `claude-sonnet-4-5-20250929`). The entire codebase, including the Flutter/Dart implementation, database architecture, BGG API integration, NFC functionality, and UI/UX design, was generated through collaborative conversation with the project owner.

## Features

### BoardGameGeek Integration
- **Collection Sync**: Import your board game collection from BoardGameGeek using their API v2
- **BGG Search**: Search the entire BGG database to add games not in your collection
- **Game Details**: View comprehensive game information including description, categories, mechanics, and expansions
- **API Token Auth**: Secure authentication using BGG API tokens

### Collection Management
- **Multiple Views**:
  - **Collection**: View your owned games
  - **All Games**: See all games in your database (owned and wishlist)
  - **Recently Played**: Quick access to games you've played, sorted by last play date
  - **Wishlist**: Dedicated view for games you want to add to your collection
  - **Scheduled Games**: See all upcoming game sessions in one place
- **Smart Filtering**: Filter by base games only, expansions only, or show all
- **Search**: Fast local search across your entire collection

### Physical Location Tracking
- **Shelf & Bay System**: Track game locations using a shelf/bay format (e.g., "A1" = Shelf A, Bay 1)
- **Visual Location Picker**: Easy-to-use grid picker for selecting locations
- **Shelf View**: See all games on a specific shelf, grouped by bay
- **NFC Shelf Tags**: Write shelf locations to NFC tags for quick navigation

### NFC Tag Support
- **Game Tags**: Write game IDs to NFC tags in your game boxes
- **Quick Scan**: Scan any tagged game box to instantly view its details
- **Record Play via NFC**: Scan a game tag to quickly record a play session
- **Shelf Navigation**: Scan shelf tags to view all games in that location

### Play Tracking
- **Record Plays**: Log when you play each game with date selection
- **Win/Loss Tracking**: Track your wins and losses for competitive games
- **Play History**: View complete play history for each game
- **Edit & Delete**: Modify or remove play records as needed
- **Statistics**: See play count and win/loss record in the recently played view

### Game Scheduling & Sharing
- **Schedule Sessions**: Plan future game sessions with date, time, and location
- **Scheduled Games List**: View all upcoming game sessions in a dedicated screen (accessible from side menu)
- **Edit & Delete**: Modify or cancel scheduled sessions
- **Share Game Night Invites**: Generate shareable game session invite cards with blue gradient backgrounds
- **Share Games**: Share any game with a custom card featuring:
  - Green gradient background
  - Game details (players, playtime, rating)
  - Direct link to BoardGameGeek for easy reference

### Data Management
- **Offline First**: Full SQLite database for offline access to your collection
- **Export Backup**: Create database backups to save to iCloud Drive or Files
- **Restore Backup**: Restore your collection from a backup file
- **Image Caching**: Game images cached for offline viewing

## Screenshots

*Coming soon*

## Requirements

- iOS 13.0 or higher
- iPhone 7 or newer (for NFC hardware)
- BoardGameGeek account
- BGG API token (for collection sync)

## Installation

### Prerequisites

- Flutter SDK 3.0.0 or higher
- Xcode (for iOS development)
- CocoaPods

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/gamekeepr.git
   cd gamekeepr
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Install iOS dependencies:
   ```bash
   cd ios && pod install && cd ..
   ```

4. Run the app:
   ```bash
   flutter run
   ```

### iOS Configuration

The app requires NFC capabilities. These are already configured in the project:

- NFC Tag Reading capability is enabled in the Xcode project
- `Info.plist` includes required NFC usage descriptions

## Getting Started

### Initial Setup

1. Open the app and go to **Settings** (gear icon in the navigation drawer)
2. Enter your **BoardGameGeek username**
3. Enter your **BGG API token** (obtain from BGG account settings)
4. Tap **Save Settings**
5. Return to the home screen and tap the **sync button** to import your collection

### Using NFC Tags

#### Writing Game Tags
1. Open a game's details screen
2. Tap the **NFC icon** in the app bar
3. Hold your iPhone near an NFC tag
4. Wait for the success confirmation

#### Scanning Game Tags
1. From the home screen, tap the **NFC menu** (NFC icon)
2. Select **Scan Tag**
3. Hold your iPhone near a tagged game box
4. The game's details screen will open automatically

#### Recording Plays via NFC
1. Tap the **NFC menu** and select **Record Play**
2. Scan a game's NFC tag
3. Select the date and win/loss status
4. Save the play record

### Managing Locations

1. Open a game's details screen
2. Scroll to the **Set Location** section
3. Use the grid picker to select shelf (A-H) and bay (1-8)
4. Location saves automatically

### Viewing Shelf Contents

1. Scan a shelf NFC tag, or
2. Navigate to a game with a location set and tap the location badge

### Sharing Games

#### Share a Game
1. Open any game's details screen
2. Tap the **share icon** in the app bar
3. A shareable card will be generated with:
   - Game image and details
   - BoardGameGeek link
4. Share via Messages, Mail, or any other app

#### Share a Scheduled Game Session
1. Open a game's details screen
2. Navigate to the **Scheduled** tab
3. Tap the **share icon** next to a scheduled session
4. Share the game night invitation

### Viewing Scheduled Games

Access all your upcoming game sessions from the side menu:
1. Open the navigation drawer (tap the menu icon)
2. Tap **Scheduled Games**
3. View all scheduled sessions sorted by date
4. Games scheduled for today are highlighted in orange
5. Tap any game to view full details

## Technical Details

### Architecture

- **Framework**: Flutter
- **State Management**: Riverpod
- **Local Database**: SQLite (sqflite)
- **HTTP Client**: Dio with cookie management
- **NFC**: nfc_manager package
- **Image Caching**: cached_network_image

### Project Structure

```
lib/
├── models/           # Data models (Game, Play, ScheduledGame)
├── providers/        # Riverpod providers and state management
├── screens/          # UI screens
├── services/         # Business logic (Database, BGG API, NFC)
├── widgets/          # Reusable UI components
└── constants/        # App constants
```

### BGG API Integration

The app uses BoardGameGeek's XML API v2:
- Collection endpoint: `/xmlapi2/collection` - Fetch user's game collection
- Thing endpoint: `/xmlapi2/thing` - Get detailed game information

## Troubleshooting

### NFC Issues

- **NFC not working**: Ensure you have iPhone 7 or newer
- **Tag not recognized**: Make sure the tag was written by this app
- **Write failed**: Try holding the phone still and closer to the tag

### Sync Problems

- **Authentication failed**: Verify your BGG API token is correct
- **Empty collection**: Check that games in BGG are marked as "owned"
- **Slow sync**: Large collections may take several minutes; BGG API has rate limits

### Data Issues

- **Games missing**: Try syncing again from the home screen
- **Corrupted data**: Use Settings > Clear All Data, then re-sync
- **Lost data**: Restore from a backup file in Settings

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [BoardGameGeek](https://boardgamegeek.com) for their comprehensive game database and API
- The Flutter and Dart teams for an excellent framework
- All the board game enthusiasts who inspired this project

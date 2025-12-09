# Game Keepr

A mobile Flutter application for managing your board game collection with NFC tag support, BoardGameGeek integration, and shelf location tracking.

## About This Project

This application was entirely written by **Claude** (Anthropic's AI assistant), specifically using **Claude Sonnet 4.5** (model: `claude-sonnet-4-5-20250929`). The entire codebase, including the Flutter/Dart implementation, database architecture, BGG API integration, NFC functionality, and UI/UX design, was generated through collaborative conversation with the project owner.

## Features

### BoardGameGeek Integration
- **Collection Sync**: Import your board game collection from BoardGameGeek using their API v2
- **Ownership Sync**: Automatically sync ownership status changes back to BGG when you add or remove games
- **Play History Sync**: Import play history from BGG for each game (synced plays are marked as read-only)
- **BGG Search**: Search the entire BGG database to add games not in your collection
- **Game Details**: View comprehensive game information including description, categories, mechanics, and expansions
- **API Token Auth**: Secure authentication using BGG API tokens and password for write operations

### Collection Management
- **Multiple Views**:
  - **Collection**: View your owned games
  - **All Games**: See all games in your database (owned and wishlist)
  - **Recently Played**: Quick access to games you've played, sorted by last play date
  - **Wishlist**: Dedicated view for games you want to add to your collection
  - **Scheduled Games**: See all upcoming game sessions in one place
- **Smart Filtering**: Filter by base games only, expansions only, or show all
- **Search**: Fast local search across your entire collection with optional filters for categories, mechanics, and tags

### Physical Location Tracking
- **Shelf & Bay System**: Track game locations using a shelf/bay format (e.g., "A1" = Shelf A, Bay 1)
- **Visual Location Picker**: Easy-to-use grid picker for selecting locations
- **Shelf View**: See all games on a specific shelf, grouped by bay
- **NFC Shelf Tags**: Write shelf locations to NFC tags for quick navigation

### Game Tagging
- **Custom Tags**: Add custom tags to organize your games (e.g., "party", "family-friendly", "quick-play")
- **Multi-Tag Support**: Add multiple tags to each game separated by commas
- **Color-Coded Display**: Tags are automatically color-coded for easy visual identification
- **Tag Management**: Centralized screen to rename or delete tags across your entire collection
- **Usage Tracking**: See how many games each tag is applied to before deleting
- **Searchable**: Search your collection by tags along with categories and mechanics

### NFC Tag Support
- **Game Tags**: Write game IDs to NFC tags in your game boxes
- **Quick Scan**: Scan any tagged game box to instantly view its details
- **Record Play via NFC**: Scan a game tag to quickly record a play session
- **Shelf Navigation**: Scan shelf tags to view all games in that location

### Game Recognition (Experimental)
- **Photo Recognition**: Take a photo of your game shelf to identify games by their spines
- **OCR Technology**: Uses Google ML Kit to extract text from game spine images
- **Fuzzy Matching**: Intelligent matching algorithm compares extracted text against your collection
- **Confidence Scoring**: Results ranked by confidence (high/medium/low) to help identify accurate matches
- **Inline NFC Writing**: Write NFC tags directly from the recognition results screen
- **Multiple Sources**: Capture photos with your camera or select from your photo library
- **Note**: This is an experimental feature; recognition accuracy may vary based on image quality and text clarity

### Play Tracking
- **Record Plays**: Log when you play each game with date selection
- **Win/Loss Tracking**: Track your wins and losses for competitive games
- **BGG Play Sync**: Automatically import play history from BGG when syncing game details
- **Read-Only Synced Plays**: Plays synced from BGG are marked with a cloud icon and cannot be edited/deleted
- **Manual Plays**: Create your own play records that can be edited and deleted
- **Play History**: View complete play history for each game with clear indicators for synced vs. manual plays
- **Statistics**: See play count and win/loss record in the recently played view

### Game Loan Tracking
- **Loan Games**: Track which games you've lent out and to whom
- **Borrower Management**: Free-text borrower names with autocomplete
- **Active Loans View**: See all currently loaned games in one place (accessible from side menu)
- **Loan History**: View complete loan history for each game including return dates
- **NFC Loan Recording**: Scan a game tag to quickly create a loan record
- **Return Tracking**: Mark games as returned with automatic date logging

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

The app requires NFC and camera capabilities. These are already configured in the project:

- NFC Tag Reading capability is enabled in the Xcode project
- `Info.plist` includes required usage descriptions:
  - `NFCReaderUsageDescription` for NFC tag reading/writing
  - `NSCameraUsageDescription` for taking photos of game shelves
  - `NSPhotoLibraryUsageDescription` for selecting photos from library

## Getting Started

### Initial Setup

1. Open the app and go to **Settings** (gear icon in the navigation drawer)
2. Enter your **BoardGameGeek username**
3. *(Optional)* Enter your **BGG password** to enable two-way sync (ownership changes will sync back to BGG)
4. Enter your **BGG API token** (obtain from BGG account settings)
5. Tap **Save Settings**
6. Return to the home screen and tap the **sync button** to import your collection

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

### Using Game Tags

#### Adding Tags to Games
1. Open a game's details screen
2. Navigate to the **Tags** tab (label icon)
3. Type tags separated by commas (e.g., "party,family,quick")
4. Press the **+** button or Enter to add
5. Tags are automatically converted to lowercase for consistency

#### Managing Tags
1. Open the navigation drawer (menu icon)
2. Tap **Manage Tags**
3. View all tags with their usage counts
4. **Rename a tag**: Tap the edit icon to rename across all games
5. **Delete a tag**: Tap the delete icon (shows usage count in confirmation)

#### Searching by Tags
1. From the home screen, enter a search term
2. Check the **Tags** checkbox that appears
3. Search will now include matching tags

### Using Game Recognition (Experimental)

#### Recognizing Games from Photos
1. Open the navigation drawer (menu icon)
2. Tap **Recognize Games**
3. Choose **Take Photo** to capture a new image or **Choose from Gallery** to select an existing photo
4. Take a clear photo of your game shelf showing the game spines
5. Tap **Find Games** to process the image
6. View the matched games with confidence scores:
   - 🟢 **High confidence** (≥70%): Strong match
   - 🟠 **Medium confidence** (50-69%): Probable match
   - ⚪ **Low confidence** (<50%): Uncertain match

#### Writing NFC Tags from Recognition Results
1. After processing a photo, view the results list
2. Games without NFC tags will show a blue NFC icon button
3. Tap the NFC icon button to write a tag
4. Hold your iPhone near an NFC tag
5. After successful write, the button disappears and "NFC Tag" label appears
6. Continue writing tags for other games in the list

**Tips for Best Results:**
- Ensure good lighting when taking photos
- Keep text on game spines clearly visible and in focus
- Avoid glare and shadows on the spines
- Hold the camera parallel to the shelf for clearer text
- Recognition works best with clear, printed text

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
- **OCR**: Google ML Kit Text Recognition
- **Text Matching**: string_similarity for fuzzy matching
- **Image Capture**: image_picker and camera packages

### Project Structure

```
lib/
├── models/           # Data models (Game, Play, ScheduledGame, GameLoan)
├── providers/        # Riverpod providers and state management
├── screens/          # UI screens (home, game details, manage tags, etc.)
├── services/         # Business logic (Database, BGG API, NFC)
├── widgets/          # Reusable UI components (location picker, tag widget, etc.)
└── constants/        # App constants
```

### BGG API Integration

The app uses BoardGameGeek's API:
- **XML API v2** (read operations):
  - Collection endpoint: `/xmlapi2/collection` - Fetch user's game collection
  - Thing endpoint: `/xmlapi2/thing` - Get detailed game information
  - Plays endpoint: `/xmlapi2/plays` - Fetch play history for games
- **REST API** (write operations):
  - Login endpoint: `/login/api/v1` - Authenticate for write access
  - Collection items endpoint: `/api/collectionitems` - Update ownership status

## Troubleshooting

### Game Recognition Issues

- **No games found**: Ensure the photo shows clear, readable text on game spines
- **Poor accuracy**: Try retaking the photo with better lighting and less glare
- **Camera permission denied**: Go to Settings > GameKeepr and enable Camera access
- **Inconsistent results**: The feature is experimental; results may vary based on image quality, lighting, and text legibility

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

This project is licensed under the **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License** (CC BY-NC-SA 4.0).

**You are free to:**
- Use, modify, and share this code for personal and non-commercial purposes
- Build upon this work and create derivative applications

**Under these terms:**
- **Attribution**: You must give appropriate credit
- **NonCommercial**: You may not use this for commercial purposes or sell it
- **ShareAlike**: Any derivatives must use the same license

See the [LICENSE](LICENSE) file for full details or visit https://creativecommons.org/licenses/by-nc-sa/4.0/

## Acknowledgments

- [BoardGameGeek](https://boardgamegeek.com) for their comprehensive game database and API
- The Flutter and Dart teams for an excellent framework
- All the board game enthusiasts who inspired this project

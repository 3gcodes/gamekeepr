# Game Keepr

A mobile Flutter application for managing your board game collection with NFC tag support, BoardGameGeek integration, shelf location tracking, and collectibles management.

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
- **Three Main Tabs**:
  - **Games**: Manage your board game collection with nested tabs
    - **Collection**: View your owned games
    - **Wishlist**: Games you want to add to your collection
    - **Saved for Later**: Bookmarked games for future consideration
  - **Collectibles**: Track miniatures, special editions, Kickstarter exclusives, and other game-related items
  - **More**: Access to secondary features (Recently Played, Scheduled Games, Loaned Games, tools, and settings)
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

### Collectibles Management
- **Track Anything Game-Related**: Manage miniatures, painted figures, special editions, Kickstarter exclusives, promos, custom components, and more
- **Multi-Image Support**: Add up to 3 photos per collectible with designated cover image
- **Game Association**: Link collectibles to games in your collection for easy organization
- **Full-Screen Image Viewer**: View collectible photos in full-screen with swipe navigation and pinch-to-zoom
- **Location Tracking**: Track shelf/bay locations for collectibles just like games
- **NFC Tag Support**: Write and scan NFC tags for quick collectible access
- **Shelf View Integration**: See collectibles alongside games when viewing a specific shelf location
- **Search & Filter**: Search collectibles by name with real-time filtering
- **Cloud Storage (Optional)**: Store collectible images in Amazon S3 for cloud backup and multi-device access
- **Backup & Restore**: Collectible images are automatically included in database backups

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
- **Active Loans View**: See all currently loaned games in one place (accessible from More tab)
- **Loan History**: View complete loan history for each game including return dates
- **NFC Loan Recording**: Scan a game tag to quickly create a loan record
- **Return Tracking**: Mark games as returned with automatic date logging

### Game Scheduling & Sharing
- **Schedule Sessions**: Plan future game sessions with date, time, and location
- **Scheduled Games List**: View all upcoming game sessions in a dedicated screen (accessible from More tab)
- **Edit & Delete**: Modify or cancel scheduled sessions
- **Share Game Night Invites**: Generate shareable game session invite cards with blue gradient backgrounds
- **Share Games**: Share any game with a custom card featuring:
  - Green gradient background
  - Game details (players, playtime, rating)
  - Direct link to BoardGameGeek for easy reference

### Data Management
- **Offline First**: Full SQLite database for offline access to your collection
- **Export Backup**: Create comprehensive backup archives (ZIP format) containing database + all collectible images
- **Restore Backup**: Restore your collection and collectible images from a backup file
- **Image Caching**: Game images cached for offline viewing
- **Flexible Storage**: Choose between local storage (default) or Amazon S3 for collectible images
- **S3 Cloud Storage**: Optional integration with Amazon S3 for cloud-based image storage with signed URLs for security

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

1. Open the app and navigate to the **More** tab
2. Tap **Settings** from the menu
3. Enter your **BoardGameGeek username**
4. *(Optional)* Enter your **BGG password** to enable two-way sync (ownership changes will sync back to BGG)
5. Enter your **BGG API token** (obtain from BGG account settings)
6. Tap **Save Settings**
7. Return to the **Games** tab and tap the **sync button** to import your collection

### Using NFC Tags

The app features a **floating action button (NFC icon)** accessible from all tabs for quick NFC operations.

#### Writing Game Tags
1. Open a game's details screen
2. Tap the **NFC icon** in the app bar
3. Hold your iPhone near an NFC tag
4. Wait for the success confirmation

#### Scanning Game Tags
1. From any tab, tap the **floating NFC button**
2. Select **Scan Tag**
3. Hold your iPhone near a tagged game box
4. The game or collectible details screen will open automatically

#### Recording Plays via NFC
1. Tap the **floating NFC button** and select **Record Play**
2. Scan a game's NFC tag
3. Select the date and win/loss status
4. Save the play record

#### Writing Collectible Tags
1. Open a collectible's details screen
2. Tap the **NFC icon** in the app bar
3. Hold your iPhone near an NFC tag
4. Wait for the success confirmation

### Managing Locations

1. Open a game's details screen
2. Scroll to the **Set Location** section
3. Use the grid picker to select shelf (A-H) and bay (1-8)
4. Location saves automatically

### Viewing Shelf Contents

1. Scan a shelf NFC tag, or
2. Navigate to a game with a location set and tap the location badge

### Using Save for Later

Save games you're interested in but not ready to wishlist or purchase yet. Unlike the wishlist, this is for games you want to keep track of for future consideration.

#### Saving Games for Later
1. Open a non-owned game's details screen
2. In the ownership banner at the top, tap the **"Save"** button (bookmark icon)
3. The button will change to **"Saved"** with a filled orange bookmark icon

#### Viewing Saved Games
1. Navigate to the **Games** tab
2. Select the **Saved** sub-tab
3. View all games you've saved
4. Use the search bar to filter saved games
5. Tap any game to view full details

#### Removing from Save for Later
1. Open a saved game's details screen
2. Tap the **"Saved"** button to toggle it off

**Note**: Only non-owned games can be saved for later. A game can be both on your wishlist AND saved for later.

### Using Game Tags

#### Adding Tags to Games
1. Open a game's details screen
2. Navigate to the **Tags** tab (label icon)
3. Type tags separated by commas (e.g., "party,family,quick")
4. Press the **+** button or Enter to add
5. Tags are automatically converted to lowercase for consistency

#### Managing Tags
1. Navigate to the **More** tab
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
1. Navigate to the **More** tab
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

### Managing Collectibles

Track miniatures, special editions, and other game-related items in the dedicated Collectibles tab.

#### Adding a Collectible
1. Navigate to the **Collectibles** tab
2. Tap the **+ (Add Collectible)** floating action button
3. Enter the collectible name
4. Optionally select an associated game from your collection
5. Add up to 3 photos by tapping the camera icons
6. Designate one photo as the cover image (shown in lists)
7. Set a shelf location if desired
8. Tap **Save Collectible**

#### Viewing Collectibles
1. Navigate to the **Collectibles** tab
2. Browse all collectibles with cover images
3. Use the search bar to filter by name
4. Tap any collectible to view full details

#### Viewing Collectible Images
1. Open a collectible's details screen
2. Tap any image to view it full-screen
3. Swipe left/right to navigate between images
4. Pinch to zoom in on details
5. Cover images are marked with a "Cover Photo" badge
6. Tap the X to exit the image viewer

#### Editing Collectibles
1. Open a collectible's details screen
2. Tap the **Edit** button in the app bar
3. Modify any details (name, associated game, location)
4. Add or remove photos (up to 3 total)
5. Change the cover image if desired
6. Tap **Save Changes**

#### Deleting Collectibles
1. Open a collectible's details screen
2. Tap the **Delete** icon in the app bar
3. Confirm the deletion
4. All associated photos and data will be permanently removed

### Configuring S3 Cloud Storage (Optional)

Store your collectible images in Amazon S3 for cloud backup and multi-device access.

#### Setting Up S3 Storage
1. Navigate to the **More** tab
2. Tap **Settings**
3. Scroll to the **S3 Storage (Optional)** section
4. Toggle **Enable S3 Storage** on
5. Enter your S3 configuration:
   - **S3 Bucket Name**: Your AWS S3 bucket name
   - **S3 Region**: AWS region (e.g., us-east-1)
   - **Access Key ID**: Your AWS access key
   - **Secret Access Key**: Your AWS secret key
6. Tap **Save Settings**

#### How S3 Storage Works
- **New Images**: Automatically uploaded to S3 when you add collectibles
- **Existing Images**: Remain in local storage; only new images use S3
- **Security**: All S3 URLs are pre-signed with 7-day expiration
- **Caching**: S3 images are cached locally for offline viewing
- **Fallback**: If S3 is disabled, the app reverts to local storage
- **No Public Access**: S3 bucket does not need public access; signed URLs provide secure access

**Note**: You'll need an AWS account and S3 bucket. Ensure your AWS credentials have permissions to upload to the specified bucket.

### Viewing Scheduled Games

Access all your upcoming game sessions from the More tab:
1. Navigate to the **More** tab
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
- **Cloud Storage**: Amazon S3 with AWS Signature V4 (crypto package)

### Project Structure

```
lib/
├── models/           # Data models (Game, Play, ScheduledGame, GameLoan, Collectible)
├── providers/        # Riverpod providers and state management
├── screens/          # UI screens (home, games tab, collectibles, more tab, etc.)
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

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/game.dart';
import '../models/play.dart';
import '../models/scheduled_game.dart';
import '../models/game_loan.dart';
import '../models/game_with_loan_info.dart';
import '../models/game_with_play_info.dart';
import '../models/collectible.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gamekeepr.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 15,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE games (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bgg_id INTEGER UNIQUE NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        image_url TEXT,
        thumbnail_url TEXT,
        year_published INTEGER,
        min_players INTEGER,
        max_players INTEGER,
        min_playtime INTEGER,
        max_playtime INTEGER,
        average_rating REAL,
        location TEXT,
        last_synced TEXT,
        categories TEXT,
        mechanics TEXT,
        base_game TEXT,
        expansions TEXT,
        owned INTEGER NOT NULL DEFAULT 1,
        wishlisted INTEGER NOT NULL DEFAULT 0,
        saved_for_later INTEGER NOT NULL DEFAULT 0,
        has_nfc_tag INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create index on bgg_id for faster lookups
    await db.execute('''
      CREATE INDEX idx_bgg_id ON games(bgg_id)
    ''');

    // Create index on name for search
    await db.execute('''
      CREATE INDEX idx_name ON games(name)
    ''');

    // Create plays table
    await db.execute('''
      CREATE TABLE plays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        date_played TEXT NOT NULL,
        created_at TEXT NOT NULL,
        won INTEGER,
        synced_from_bgg INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE
      )
    ''');

    // Create index on game_id for faster lookups
    await db.execute('''
      CREATE INDEX idx_plays_game_id ON plays(game_id)
    ''');

    // Create index on date_played for sorting
    await db.execute('''
      CREATE INDEX idx_plays_date ON plays(date_played)
    ''');

    // Create scheduled_games table
    await db.execute('''
      CREATE TABLE scheduled_games (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        scheduled_date_time TEXT NOT NULL,
        location TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE
      )
    ''');

    // Create index on game_id for faster lookups
    await db.execute('''
      CREATE INDEX idx_scheduled_game_id ON scheduled_games(game_id)
    ''');

    // Create index on scheduled_date_time for sorting
    await db.execute('''
      CREATE INDEX idx_scheduled_date ON scheduled_games(scheduled_date_time)
    ''');

    // Create game_loans table
    await db.execute('''
      CREATE TABLE game_loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        borrower_name TEXT NOT NULL,
        loan_date TEXT NOT NULL,
        return_date TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE
      )
    ''');

    // Create index on game_id for faster lookups
    await db.execute('''
      CREATE INDEX idx_loan_game_id ON game_loans(game_id)
    ''');

    // Create index on loan_date for sorting
    await db.execute('''
      CREATE INDEX idx_loan_date ON game_loans(loan_date)
    ''');

    // Create game_tags table
    await db.execute('''
      CREATE TABLE game_tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        tag TEXT NOT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE,
        UNIQUE(game_id, tag)
      )
    ''');

    // Create index on game_id for faster lookups
    await db.execute('''
      CREATE INDEX idx_tag_game_id ON game_tags(game_id)
    ''');

    // Create index on tag for faster searches and autocomplete
    await db.execute('''
      CREATE INDEX idx_tag ON game_tags(tag)
    ''');

    // Create collectibles table
    await db.execute('''
      CREATE TABLE collectibles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        game_id INTEGER,
        manufacturer TEXT,
        description TEXT,
        painted INTEGER NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 1,
        location TEXT,
        has_nfc_tag INTEGER NOT NULL DEFAULT 0,
        image_url TEXT,
        images TEXT,
        cover_image_index INTEGER NOT NULL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE SET NULL
      )
    ''');

    // Create index on game_id for faster lookups
    await db.execute('''
      CREATE INDEX idx_collectible_game_id ON collectibles(game_id)
    ''');

    // Create index on type for filtering
    await db.execute('''
      CREATE INDEX idx_collectible_type ON collectibles(type)
    ''');

    // Create index on name for search
    await db.execute('''
      CREATE INDEX idx_collectible_name ON collectibles(name)
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add plays table for version 2
      await db.execute('''
        CREATE TABLE plays (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          game_id INTEGER NOT NULL,
          date_played TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_plays_game_id ON plays(game_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_plays_date ON plays(date_played)
      ''');
    }

    if (oldVersion < 3) {
      // Add won column for version 3
      await db.execute('''
        ALTER TABLE plays ADD COLUMN won INTEGER
      ''');
    }

    if (oldVersion < 4) {
      // Add categories and mechanics columns for version 4
      await db.execute('''
        ALTER TABLE games ADD COLUMN categories TEXT
      ''');
      await db.execute('''
        ALTER TABLE games ADD COLUMN mechanics TEXT
      ''');
    }

    if (oldVersion < 5) {
      // Add base_game and expansions columns for version 5
      await db.execute('''
        ALTER TABLE games ADD COLUMN base_game TEXT
      ''');
      await db.execute('''
        ALTER TABLE games ADD COLUMN expansions TEXT
      ''');
    }

    if (oldVersion < 6) {
      // Add owned column for version 6 - default to 1 (true) for existing games
      await db.execute('''
        ALTER TABLE games ADD COLUMN owned INTEGER NOT NULL DEFAULT 1
      ''');
    }

    if (oldVersion < 7) {
      // Add wishlisted column for version 7 - default to 0 (false) for existing games
      await db.execute('''
        ALTER TABLE games ADD COLUMN wishlisted INTEGER NOT NULL DEFAULT 0
      ''');
    }

    if (oldVersion < 8) {
      // Add scheduled_games table for version 8
      await db.execute('''
        CREATE TABLE scheduled_games (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          game_id INTEGER NOT NULL,
          scheduled_date_time TEXT NOT NULL,
          location TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_scheduled_game_id ON scheduled_games(game_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_scheduled_date ON scheduled_games(scheduled_date_time)
      ''');
    }

    if (oldVersion < 9) {
      // Add has_nfc_tag column for version 9 - default to 0 (false) for existing games
      await db.execute('''
        ALTER TABLE games ADD COLUMN has_nfc_tag INTEGER NOT NULL DEFAULT 0
      ''');
    }

    if (oldVersion < 10) {
      // Add game_loans table for version 10
      await db.execute('''
        CREATE TABLE game_loans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          game_id INTEGER NOT NULL,
          borrower_name TEXT NOT NULL,
          loan_date TEXT NOT NULL,
          return_date TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_loan_game_id ON game_loans(game_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_loan_date ON game_loans(loan_date)
      ''');
    }

    if (oldVersion < 11) {
      // Add game_tags table for version 11
      await db.execute('''
        CREATE TABLE game_tags (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          game_id INTEGER NOT NULL,
          tag TEXT NOT NULL,
          FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE,
          UNIQUE(game_id, tag)
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_tag_game_id ON game_tags(game_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_tag ON game_tags(tag)
      ''');
    }

    if (oldVersion < 12) {
      // Add synced_from_bgg column to plays table for version 12
      await db.execute('''
        ALTER TABLE plays ADD COLUMN synced_from_bgg INTEGER NOT NULL DEFAULT 0
      ''');
    }

    if (oldVersion < 13) {
      // Add saved_for_later column for version 13 - default to 0 (false) for existing games
      await db.execute('''
        ALTER TABLE games ADD COLUMN saved_for_later INTEGER NOT NULL DEFAULT 0
      ''');
    }

    if (oldVersion < 14) {
      // Add collectibles table for version 14
      await db.execute('''
        CREATE TABLE collectibles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          name TEXT NOT NULL,
          game_id INTEGER,
          manufacturer TEXT,
          description TEXT,
          painted INTEGER NOT NULL DEFAULT 0,
          quantity INTEGER NOT NULL DEFAULT 1,
          location TEXT,
          has_nfc_tag INTEGER NOT NULL DEFAULT 0,
          image_url TEXT,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE SET NULL
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_collectible_game_id ON collectibles(game_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_collectible_type ON collectibles(type)
      ''');

      await db.execute('''
        CREATE INDEX idx_collectible_name ON collectibles(name)
      ''');
    }

    if (oldVersion < 15) {
      // Add multiple images support for collectibles (version 15)
      await db.execute('''
        ALTER TABLE collectibles ADD COLUMN images TEXT
      ''');

      await db.execute('''
        ALTER TABLE collectibles ADD COLUMN cover_image_index INTEGER NOT NULL DEFAULT 0
      ''');

      // Migrate existing image_url data to images array
      final collectibles = await db.query('collectibles');
      for (final collectible in collectibles) {
        final imageUrl = collectible['image_url'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          // Convert single image_url to JSON array
          final imagesJson = '["$imageUrl"]';
          await db.update(
            'collectibles',
            {'images': imagesJson, 'cover_image_index': 0},
            where: 'id = ?',
            whereArgs: [collectible['id']],
          );
        }
      }
    }
  }

  Future<Game> insertGame(Game game) async {
    final db = await database;
    final id = await db.insert(
      'games',
      game.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return game.copyWith(id: id);
  }

  Future<Game?> getGameById(int id) async {
    final db = await database;
    final maps = await db.query(
      'games',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Game.fromMap(maps.first);
  }

  Future<Game?> getGameByBggId(int bggId) async {
    final db = await database;
    final maps = await db.query(
      'games',
      where: 'bgg_id = ?',
      whereArgs: [bggId],
    );

    if (maps.isEmpty) return null;
    return Game.fromMap(maps.first);
  }

  Future<List<Game>> getAllGames({String? orderBy}) async {
    final db = await database;
    final maps = await db.query(
      'games',
      orderBy: orderBy ?? 'name ASC',
    );

    return maps.map((map) => Game.fromMap(map)).toList();
  }

  Future<List<Game>> searchGames(String query) async {
    final db = await database;
    final maps = await db.query(
      'games',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );

    return maps.map((map) => Game.fromMap(map)).toList();
  }

  Future<int> updateGame(Game game) async {
    final db = await database;
    return await db.update(
      'games',
      game.toMap(),
      where: 'id = ?',
      whereArgs: [game.id],
    );
  }

  Future<int> updateGameLocation(int gameId, String location) async {
    final db = await database;
    return await db.update(
      'games',
      {'location': location},
      where: 'id = ?',
      whereArgs: [gameId],
    );
  }

  Future<int> updateGameOwned(int gameId, bool owned) async {
    final db = await database;
    return await db.update(
      'games',
      {'owned': owned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [gameId],
    );
  }

  Future<int> updateGameWishlisted(int gameId, bool wishlisted) async {
    final db = await database;
    return await db.update(
      'games',
      {'wishlisted': wishlisted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [gameId],
    );
  }

  Future<int> updateGameSavedForLater(int gameId, bool savedForLater) async {
    final db = await database;
    return await db.update(
      'games',
      {'saved_for_later': savedForLater ? 1 : 0},
      where: 'id = ?',
      whereArgs: [gameId],
    );
  }

  Future<int> updateGameHasNfcTag(int gameId, bool hasNfcTag) async {
    final db = await database;
    return await db.update(
      'games',
      {'has_nfc_tag': hasNfcTag ? 1 : 0},
      where: 'id = ?',
      whereArgs: [gameId],
    );
  }

  Future<List<Game>> getWishlistedGames() async {
    final db = await database;
    final maps = await db.query(
      'games',
      where: 'wishlisted = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Game.fromMap(map)).toList();
  }

  Future<List<Game>> getSavedForLaterGames() async {
    final db = await database;
    final maps = await db.query(
      'games',
      where: 'saved_for_later = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Game.fromMap(map)).toList();
  }

  Future<int> deleteGame(int id) async {
    final db = await database;
    return await db.delete(
      'games',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllGames() async {
    final db = await database;
    await db.delete('games');
  }

  Future<int> getGameCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM games');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Export database to a file for backup
  /// Returns the path to the exported file in a shareable location
  Future<String> exportDatabase() async {
    // Get the database path
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'gamekeepr.db'));

    // Use temporary directory which is accessible for sharing
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = join(tempDir.path, 'gamekeepr_backup_$timestamp.db');

    // Copy the database file
    await dbFile.copy(backupPath);

    print('📦 Database exported to: $backupPath');
    return backupPath;
  }

  /// Restore database from a backup file
  Future<void> restoreDatabase(String backupFilePath) async {
    // Close the current database connection
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    // Get the database path
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'gamekeepr.db'));

    // Copy the backup file to the database location
    final backupFile = File(backupFilePath);
    await backupFile.copy(dbFile.path);

    // Reinitialize the database
    _database = await _initDB('gamekeepr.db');

    print('📥 Database restored from: $backupFilePath');
  }

  /// Insert a new play record
  Future<Play> insertPlay(Play play) async {
    final db = await database;
    final id = await db.insert(
      'plays',
      play.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return play.copyWith(id: id);
  }

  /// Get all plays for a specific game
  Future<List<Play>> getPlaysForGame(int gameId) async {
    final db = await database;
    final maps = await db.query(
      'plays',
      where: 'game_id = ?',
      whereArgs: [gameId],
      orderBy: 'date_played DESC',
    );

    return maps.map((map) => Play.fromMap(map)).toList();
  }

  /// Get total play count for a game
  Future<int> getPlayCountForGame(int gameId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM plays WHERE game_id = ?',
      [gameId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Update a play record
  Future<void> updatePlay(Play play) async {
    final db = await database;
    await db.update(
      'plays',
      play.toMap(),
      where: 'id = ?',
      whereArgs: [play.id],
    );
  }

  /// Delete a play record
  Future<void> deletePlay(int playId) async {
    final db = await database;
    await db.delete(
      'plays',
      where: 'id = ?',
      whereArgs: [playId],
    );
  }

  /// Get all plays (for potential future use)
  Future<List<Play>> getAllPlays() async {
    final db = await database;
    final maps = await db.query('plays', orderBy: 'date_played DESC');
    return maps.map((map) => Play.fromMap(map)).toList();
  }

  /// Get games that have been played with their most recent play date
  /// Returns a list of maps with game data and most recent play date
  Future<List<Map<String, dynamic>>> getGamesWithRecentPlays() async {
    final db = await database;

    // Query to get games with their most recent play date
    final result = await db.rawQuery('''
      SELECT
        g.*,
        MAX(p.date_played) as last_played,
        COUNT(p.id) as play_count,
        SUM(CASE WHEN p.won = 1 THEN 1 ELSE 0 END) as wins,
        SUM(CASE WHEN p.won = 0 THEN 1 ELSE 0 END) as losses
      FROM games g
      INNER JOIN plays p ON g.id = p.game_id
      GROUP BY g.id
      ORDER BY MAX(p.date_played) DESC
    ''');

    return result;
  }

  /// Get games played within a specific date range
  /// Returns a list of GameWithPlayInfo for games played in the date range
  Future<List<GameWithPlayInfo>> getGamesPlayedInDateRange(DateTime startDate, DateTime endDate) async {
    final db = await database;

    // Normalize dates to start/end of day
    final start = DateTime(startDate.year, startDate.month, startDate.day).toIso8601String();
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59).toIso8601String();

    // Query to get games played in the date range with their play stats
    final result = await db.rawQuery('''
      SELECT
        g.*,
        MAX(p.date_played) as last_played,
        COUNT(p.id) as play_count,
        SUM(CASE WHEN p.won = 1 THEN 1 ELSE 0 END) as wins,
        SUM(CASE WHEN p.won = 0 THEN 1 ELSE 0 END) as losses
      FROM games g
      INNER JOIN plays p ON g.id = p.game_id
      WHERE p.date_played >= ? AND p.date_played <= ?
      GROUP BY g.id
      ORDER BY COUNT(p.id) DESC, MAX(p.date_played) DESC
    ''', [start, end]);

    return result.map((map) => GameWithPlayInfo.fromMap(map)).toList();
  }

  // ==================== Scheduled Games Methods ====================

  /// Insert a new scheduled game
  Future<ScheduledGame> insertScheduledGame(ScheduledGame scheduledGame) async {
    final db = await database;
    final id = await db.insert(
      'scheduled_games',
      scheduledGame.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return scheduledGame.copyWith(id: id);
  }

  /// Get all scheduled games for a specific game (today and future)
  Future<List<ScheduledGame>> getScheduledGamesForGame(int gameId) async {
    final db = await database;
    // Get start of today (midnight last night) to keep today's games visible all day
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();
    final maps = await db.query(
      'scheduled_games',
      where: 'game_id = ? AND scheduled_date_time >= ?',
      whereArgs: [gameId, startOfToday],
      orderBy: 'scheduled_date_time ASC',
    );
    return maps.map((map) => ScheduledGame.fromMap(map)).toList();
  }

  /// Get all scheduled games (today and future)
  Future<List<ScheduledGame>> getAllFutureScheduledGames() async {
    final db = await database;
    // Get start of today (midnight last night) to keep today's games visible all day
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();
    final maps = await db.query(
      'scheduled_games',
      where: 'scheduled_date_time >= ?',
      whereArgs: [startOfToday],
      orderBy: 'scheduled_date_time ASC',
    );
    return maps.map((map) => ScheduledGame.fromMap(map)).toList();
  }

  /// Update a scheduled game
  Future<void> updateScheduledGame(ScheduledGame scheduledGame) async {
    final db = await database;
    await db.update(
      'scheduled_games',
      scheduledGame.toMap(),
      where: 'id = ?',
      whereArgs: [scheduledGame.id],
    );
  }

  /// Delete a scheduled game
  Future<void> deleteScheduledGame(int scheduledGameId) async {
    final db = await database;
    await db.delete(
      'scheduled_games',
      where: 'id = ?',
      whereArgs: [scheduledGameId],
    );
  }

  /// Get scheduled game by ID
  Future<ScheduledGame?> getScheduledGameById(int id) async {
    final db = await database;
    final maps = await db.query(
      'scheduled_games',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ScheduledGame.fromMap(maps.first);
  }

  // ==================== Game Loans Methods ====================

  /// Insert a new game loan
  Future<GameLoan> insertGameLoan(GameLoan loan) async {
    final db = await database;
    final id = await db.insert(
      'game_loans',
      loan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return loan.copyWith(id: id);
  }

  /// Get all loans for a specific game
  Future<List<GameLoan>> getLoansForGame(int gameId) async {
    final db = await database;
    final maps = await db.query(
      'game_loans',
      where: 'game_id = ?',
      whereArgs: [gameId],
      orderBy: 'loan_date DESC',
    );
    return maps.map((map) => GameLoan.fromMap(map)).toList();
  }

  /// Get active loan for a game (if any)
  Future<GameLoan?> getActiveLoanForGame(int gameId) async {
    final db = await database;
    final maps = await db.query(
      'game_loans',
      where: 'game_id = ? AND return_date IS NULL',
      whereArgs: [gameId],
      orderBy: 'loan_date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return GameLoan.fromMap(maps.first);
  }

  /// Get all active loans (games currently loaned out)
  Future<List<GameLoan>> getAllActiveLoans() async {
    final db = await database;
    final maps = await db.query(
      'game_loans',
      where: 'return_date IS NULL',
      orderBy: 'loan_date DESC',
    );
    return maps.map((map) => GameLoan.fromMap(map)).toList();
  }

  /// Get all active loans with game information
  Future<List<GameWithLoanInfo>> getActiveLoansWithGameInfo() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        g.*,
        l.id as loan_id,
        l.borrower_name,
        l.loan_date,
        l.return_date,
        l.created_at as loan_created_at
      FROM games g
      INNER JOIN game_loans l ON g.id = l.game_id
      WHERE l.return_date IS NULL
      ORDER BY l.loan_date DESC
    ''');

    return result.map((map) {
      final game = Game.fromMap(map);
      final loan = GameLoan(
        id: map['loan_id'] as int?,
        gameId: game.id!,
        borrowerName: map['borrower_name'] as String,
        loanDate: DateTime.parse(map['loan_date'] as String),
        returnDate: map['return_date'] != null
            ? DateTime.parse(map['return_date'] as String)
            : null,
        createdAt: DateTime.parse(map['loan_created_at'] as String),
      );
      return GameWithLoanInfo(game: game, activeLoan: loan);
    }).toList();
  }

  /// Update a loan (typically to mark as returned)
  Future<void> updateGameLoan(GameLoan loan) async {
    final db = await database;
    await db.update(
      'game_loans',
      loan.toMap(),
      where: 'id = ?',
      whereArgs: [loan.id],
    );
  }

  /// Mark a loan as returned
  Future<void> returnGame(int loanId) async {
    final db = await database;
    await db.update(
      'game_loans',
      {'return_date': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [loanId],
    );
  }

  /// Delete a loan record
  Future<void> deleteGameLoan(int loanId) async {
    final db = await database;
    await db.delete(
      'game_loans',
      where: 'id = ?',
      whereArgs: [loanId],
    );
  }

  /// Get all unique borrower names for autocomplete
  Future<List<String>> getAllBorrowerNames() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT borrower_name
      FROM game_loans
      ORDER BY borrower_name ASC
    ''');
    return result.map((row) => row['borrower_name'] as String).toList();
  }

  // ==================== Game Tags Methods ====================

  /// Add a tag to a game
  Future<void> addTagToGame(int gameId, String tag) async {
    final db = await database;
    await db.insert(
      'game_tags',
      {'game_id': gameId, 'tag': tag.trim().toLowerCase()},
      conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore if tag already exists
    );
  }

  /// Add multiple tags to a game at once
  Future<void> addTagsToGame(int gameId, List<String> tags) async {
    final db = await database;
    final batch = db.batch();
    for (final tag in tags) {
      batch.insert(
        'game_tags',
        {'game_id': gameId, 'tag': tag.trim().toLowerCase()},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Remove a tag from a game
  Future<void> removeTagFromGame(int gameId, String tag) async {
    final db = await database;
    await db.delete(
      'game_tags',
      where: 'game_id = ? AND tag = ?',
      whereArgs: [gameId, tag.toLowerCase()],
    );
  }

  /// Get all tags for a specific game
  Future<List<String>> getTagsForGame(int gameId) async {
    final db = await database;
    final result = await db.query(
      'game_tags',
      columns: ['tag'],
      where: 'game_id = ?',
      whereArgs: [gameId],
      orderBy: 'tag ASC',
    );
    return result.map((row) => row['tag'] as String).toList();
  }

  /// Get all unique tags (for autocomplete)
  Future<List<String>> getAllUniqueTags() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT tag
      FROM game_tags
      ORDER BY tag ASC
    ''');
    return result.map((row) => row['tag'] as String).toList();
  }

  /// Get all games with a specific tag
  Future<List<Game>> getGamesByTag(String tag) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT g.*
      FROM games g
      INNER JOIN game_tags t ON g.id = t.game_id
      WHERE t.tag = ?
      ORDER BY g.name ASC
    ''', [tag.toLowerCase()]);
    return result.map((map) => Game.fromMap(map)).toList();
  }

  /// Get the count of games using a specific tag
  Future<int> getTagUsageCount(String tag) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT game_id) as count
      FROM game_tags
      WHERE tag = ?
    ''', [tag.toLowerCase()]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Rename a tag across all games
  Future<void> renameTag(String oldTag, String newTag) async {
    final db = await database;
    await db.update(
      'game_tags',
      {'tag': newTag.trim().toLowerCase()},
      where: 'tag = ?',
      whereArgs: [oldTag.toLowerCase()],
    );
  }

  /// Delete a tag from all games
  Future<void> deleteTagFromAllGames(String tag) async {
    final db = await database;
    await db.delete(
      'game_tags',
      where: 'tag = ?',
      whereArgs: [tag.toLowerCase()],
    );
  }

  // ============================================================================
  // Collectibles CRUD Operations
  // ============================================================================

  /// Insert a new collectible
  Future<Collectible> insertCollectible(Collectible collectible) async {
    final db = await database;
    final now = DateTime.now();
    final collectibleWithTimestamps = collectible.copyWith(
      createdAt: collectible.createdAt ?? now,
      updatedAt: now,
    );
    final id = await db.insert(
      'collectibles',
      collectibleWithTimestamps.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return collectibleWithTimestamps.copyWith(id: id);
  }

  /// Get a collectible by ID
  Future<Collectible?> getCollectibleById(int id) async {
    final db = await database;
    final maps = await db.query(
      'collectibles',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Collectible.fromMap(maps.first);
  }

  /// Get all collectibles
  Future<List<Collectible>> getAllCollectibles({String? orderBy}) async {
    final db = await database;
    final maps = await db.query(
      'collectibles',
      orderBy: orderBy ?? 'name ASC',
    );

    return maps.map((map) => Collectible.fromMap(map)).toList();
  }

  /// Get collectibles by type
  Future<List<Collectible>> getCollectiblesByType(CollectibleType type) async {
    final db = await database;
    final maps = await db.query(
      'collectibles',
      where: 'type = ?',
      whereArgs: [type.value],
      orderBy: 'name ASC',
    );

    return maps.map((map) => Collectible.fromMap(map)).toList();
  }

  /// Get collectibles for a specific game
  Future<List<Collectible>> getCollectiblesForGame(int gameId) async {
    final db = await database;
    final maps = await db.query(
      'collectibles',
      where: 'game_id = ?',
      whereArgs: [gameId],
      orderBy: 'name ASC',
    );

    return maps.map((map) => Collectible.fromMap(map)).toList();
  }

  /// Get collectibles by location
  Future<List<Collectible>> getCollectiblesByLocation(String location) async {
    final db = await database;
    final maps = await db.query(
      'collectibles',
      where: 'location = ?',
      whereArgs: [location],
      orderBy: 'name ASC',
    );

    return maps.map((map) => Collectible.fromMap(map)).toList();
  }

  /// Search collectibles by name
  Future<List<Collectible>> searchCollectibles(String query) async {
    final db = await database;
    final maps = await db.query(
      'collectibles',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );

    return maps.map((map) => Collectible.fromMap(map)).toList();
  }

  /// Update a collectible
  Future<int> updateCollectible(Collectible collectible) async {
    final db = await database;
    final collectibleWithTimestamp = collectible.copyWith(
      updatedAt: DateTime.now(),
    );
    return await db.update(
      'collectibles',
      collectibleWithTimestamp.toMap(),
      where: 'id = ?',
      whereArgs: [collectible.id],
    );
  }

  /// Update collectible location
  Future<int> updateCollectibleLocation(int collectibleId, String location) async {
    final db = await database;
    return await db.update(
      'collectibles',
      {'location': location, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [collectibleId],
    );
  }

  /// Update collectible painted status
  Future<int> updateCollectiblePainted(int collectibleId, bool painted) async {
    final db = await database;
    return await db.update(
      'collectibles',
      {'painted': painted ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [collectibleId],
    );
  }

  /// Update collectible has NFC tag status
  Future<int> updateCollectibleHasNfcTag(int collectibleId, bool hasNfcTag) async {
    final db = await database;
    return await db.update(
      'collectibles',
      {'has_nfc_tag': hasNfcTag ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [collectibleId],
    );
  }

  /// Delete a collectible
  Future<int> deleteCollectible(int id) async {
    final db = await database;
    return await db.delete(
      'collectibles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get count of collectibles
  Future<int> getCollectibleCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM collectibles');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get count of collectibles by type
  Future<int> getCollectibleCountByType(CollectibleType type) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM collectibles WHERE type = ?',
      [type.value],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

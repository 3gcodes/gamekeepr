import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/game.dart';
import '../models/play.dart';
import '../models/scheduled_game.dart';

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
      version: 8,
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
        wishlisted INTEGER NOT NULL DEFAULT 0
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

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

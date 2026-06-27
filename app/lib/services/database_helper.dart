import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'hospital_navigation_tool.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('student_health_assistant.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create Student Profile table for key-value settings/contexts
    await db.execute('''
      CREATE TABLE student_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_key TEXT UNIQUE NOT NULL,
        profile_value TEXT NOT NULL
      )
    ''');

    // Create Conversations table
    await db.execute('''
      CREATE TABLE conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create Messages table
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        sender_type TEXT NOT NULL, -- 'user' or 'assistant'
        content_text TEXT NOT NULL,
        input_type TEXT NOT NULL, -- 'text' or 'audio'
        created_at TEXT NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE
      )
    ''');

    // Insert default profile records
    await db.insert('student_profile', {
      'profile_key': 'student_name',
      'profile_value': 'Student',
    });
    await db.insert('student_profile', {
      'profile_key': 'insurance',
      'profile_value': 'None',
    });
    await db.insert('student_profile', {
      'profile_key': 'history_summary',
      'profile_value': 'No prior health issues recorded.',
    });
    await db.insert('student_profile', {
      'profile_key': 'onboarding_complete',
      'profile_value': 'false',
    });

    // Create hospital and sync meta tables
    await _createHospitalsTable(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createHospitalsTable(db);
    }
  }

  Future<void> _createHospitalsTable(Database db) async {
    await db.execute('''
      CREATE TABLE hospitals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        district TEXT NOT NULL,
        province TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        phone TEXT,
        type TEXT,
        accepted_insurance TEXT, -- JSON array of strings
        specialties TEXT,        -- JSON array of strings
        emergency_unit INTEGER NOT NULL DEFAULT 0,
        opening_hours TEXT,
        average_rating REAL,
        rating_count INTEGER,
        average_cost_rwf INTEGER,
        average_cost_by_insurance TEXT, -- JSON map
        cost_submission_count INTEGER,
        last_updated TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE hospital_sync_meta (
        meta_key TEXT PRIMARY KEY,
        meta_value TEXT
      )
    ''');
  }

  // --- Student Profile Methods ---

  Future<String> getProfileValue(String key, {String defaultValue = ''}) async {
    final db = await instance.database;
    final maps = await db.query(
      'student_profile',
      columns: ['profile_value'],
      where: 'profile_key = ?',
      whereArgs: [key],
    );

    if (maps.isNotEmpty) {
      return maps.first['profile_value'] as String;
    }
    return defaultValue;
  }

  Future<void> setProfileValue(String key, String value) async {
    final db = await instance.database;
    await db.insert('student_profile', {
      'profile_key': key,
      'profile_value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> generateStudentProfileSummary() async {
    final name = await getProfileValue('student_name', defaultValue: 'Student');
    final insurance = await getProfileValue('insurance', defaultValue: 'None');
    final history = await getProfileValue(
      'history_summary',
      defaultValue: 'No prior health issues recorded.',
    );
    final contractSummary = await getProfileValue(
      'insurance_contract_summary',
      defaultValue: '',
    );

    // Get static coverage details
    final coverageBlock = HospitalNavigationTool.getInsuranceCoverageBlock(
      insurance,
    );

    final buffer = StringBuffer();
    buffer.writeln('### [STUDENT PROFILE]');
    buffer.writeln('Name: $name');
    buffer.writeln('Insurance Provider Specified: $insurance');
    buffer.writeln();

    buffer.writeln('### [INSURANCE COVERAGE — ${coverageBlock.providerName}]');
    buffer.writeln('Network Key: ${coverageBlock.networkKey}');
    buffer.writeln(
      'Patient Co-pay: ${coverageBlock.copayPercent.toStringAsFixed(0)}%',
    );
    buffer.writeln(
      'Requires Health Center Referral: ${coverageBlock.requiresReferral ? "YES" : "NO"}',
    );
    buffer.writeln('Referral Instructions: ${coverageBlock.referralNotes}');
    buffer.writeln('Details: ${coverageBlock.coverageDetails}');
    buffer.writeln();

    buffer.writeln('### [HEALTH HISTORY]');
    buffer.writeln(history);
    buffer.writeln();

    if (contractSummary.isNotEmpty) {
      buffer.writeln('### [INSURANCE CONTRACT]');
      buffer.writeln(contractSummary);
      buffer.writeln();
    }

    return buffer.toString();
  }

  // --- Conversations Methods ---

  Future<int> createConversation(String title) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('conversations', {
      'title': title,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    final db = await instance.database;
    return await db.query('conversations', orderBy: 'updated_at DESC');
  }

  Future<void> deleteConversation(int id) async {
    final db = await instance.database;
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
    await db.delete('messages', where: 'conversation_id = ?', whereArgs: [id]);
  }

  // --- Messages Methods ---

  Future<int> saveMessage({
    required int conversationId,
    required String text,
    required bool isUser,
    required String inputType,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();

    // Save the message
    final messageId = await db.insert('messages', {
      'conversation_id': conversationId,
      'sender_type': isUser ? 'user' : 'assistant',
      'content_text': text,
      'input_type': inputType,
      'created_at': now,
    });

    // Update conversation's updated_at timestamp
    await db.update(
      'conversations',
      {'updated_at': now},
      where: 'id = ?',
      whereArgs: [conversationId],
    );

    return messageId;
  }

  Future<List<Map<String, dynamic>>> getMessages(int conversationId) async {
    final db = await instance.database;
    return await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
  }
}

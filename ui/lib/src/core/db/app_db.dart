import 'package:flutter/rendering.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDB {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'lunar_chat.db');
    debugPrint("DB path");
    debugPrint(path);

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE chats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chat_id INTEGER NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            think TEXT,
            sequence INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            model TEXT,
            FOREIGN KEY(chat_id) REFERENCES chats(id) ON DELETE CASCADE
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_messages_chat_id ON messages(chat_id)',
        );
        await db.execute(
          'CREATE INDEX idx_messages_sequence ON messages(sequence)',
        );
      },
    );
  }
}

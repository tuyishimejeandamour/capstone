import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'hospital_navigation_tool.dart';

/// Service responsible for offline-first data sync between Firestore and SQLite.
class HospitalRepository {
  static final HospitalRepository instance = HospitalRepository._init();
  HospitalRepository._init();

  /// Retrieve all cached hospitals from local SQLite database.
  Future<List<HospitalModel>> getCachedHospitals() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query('hospitals');
      return maps.map((m) => HospitalModel.fromSQLiteMap(m)).toList();
    } catch (e) {
      debugPrint("HospitalRepository: Failed to query cached hospitals: $e");
      return [];
    }
  }

  /// Perform incremental sync of hospital data from Firestore to SQLite.
  Future<void> syncFromFirestore() async {
    try {
      // 1. Check network connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        debugPrint(
          "HospitalRepository: Device is offline. Skipping Firestore sync.",
        );
        return;
      }

      final db = await DatabaseHelper.instance.database;

      // 2. Retrieve last sync timestamp
      final meta = await db.query(
        'hospital_sync_meta',
        where: 'meta_key = ?',
        whereArgs: ['last_sync_timestamp'],
      );

      String lastSync = '';
      if (meta.isNotEmpty) {
        lastSync = meta.first['meta_value'] as String? ?? '';
      }

      debugPrint(
        "HospitalRepository: Starting sync. Last sync time: $lastSync",
      );

      // 3. Query Firestore for updated documents
      Query query = FirebaseFirestore.instance.collection('hospitals');
      if (lastSync.isNotEmpty) {
        query = query.where('lastUpdated', isGreaterThan: lastSync);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        debugPrint("HospitalRepository: SQLite cache is already up-to-date.");
        return;
      }

      debugPrint(
        "HospitalRepository: Syncing ${snapshot.docs.length} updated hospitals...",
      );

      final batch = db.batch();
      String maxLastUpdated = lastSync;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final hospital = HospitalModel.fromFirestore(doc.id, data);

        // Add to batch insert/replace
        batch.insert(
          'hospitals',
          hospital.toSQLiteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Track latest update timestamp
        if (hospital.lastUpdated.compareTo(maxLastUpdated) > 0) {
          maxLastUpdated = hospital.lastUpdated;
        }
      }

      // Save sync metadata
      batch.insert('hospital_sync_meta', {
        'meta_key': 'last_sync_timestamp',
        'meta_value': maxLastUpdated,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await batch.commit(noResult: true);
      debugPrint(
        "HospitalRepository: Sync complete. Updated last sync time to: $maxLastUpdated",
      );
    } catch (e) {
      debugPrint("HospitalRepository: Error syncing from Firestore: $e");
    }
  }

  /// Force a full refresh by clearing metadata and running sync.
  Future<void> forceRefresh() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'hospital_sync_meta',
        where: 'meta_key = ?',
        whereArgs: ['last_sync_timestamp'],
      );
      await syncFromFirestore();
    } catch (e) {
      debugPrint("HospitalRepository: Failed to force refresh: $e");
    }
  }
}

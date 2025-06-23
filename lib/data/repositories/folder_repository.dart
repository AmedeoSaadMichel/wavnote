// File: data/repositories/folder_repository.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/folder_entity.dart';
import '../../domain/repositories/i_folder_repository.dart';
import '../../core/enums/folder_type.dart';
import '../database/database_helper.dart';
import 'recording_repository_stats.dart';

/// SQLite implementation of folder repository with debugging
class FolderRepository implements IFolderRepository {
  final RecordingRepositoryStats _recordingStats = RecordingRepositoryStats();

  // ==== DEFAULT FOLDERS CONFIGURATION ====

  /// Get default system folders
  static List<FolderEntity> _getDefaultFolders() {
    return [
      FolderEntity.defaultFolder(
        id: 'all_recordings',
        name: 'All Recordings',
        icon: Icons.graphic_eq,
        color: Colors.cyan,
      ),
      FolderEntity.defaultFolder(
        id: 'favourites',
        name: 'Favourites',
        icon: Icons.favorite,
        color: Colors.red,
      ),
      FolderEntity.defaultFolder(
        id: 'recently_deleted',
        name: 'Recently Deleted',
        icon: FontAwesomeIcons.skull,
        color: Colors.yellow,
      ),
    ];
  }

  // ==== FOLDER CRUD OPERATIONS ====

  @override
  Future<List<FolderEntity>> getAllFolders() async {
    try {
      print('🔍 Getting all folders...');

      // Get custom folders from database
      final customFolders = await getCustomFolders();
      print('📁 Found ${customFolders.length} custom folders in database');

      // Get default folders and update their recording counts
      final defaultFolders = _getDefaultFolders();
      final updatedDefaultFolders = <FolderEntity>[];
      
      for (final folder in defaultFolders) {
        final recordingCount = await _recordingStats.getRecordingCountByFolder(folder.id);
        final updatedFolder = folder.copyWith(recordingCount: recordingCount);
        updatedDefaultFolders.add(updatedFolder);
        print('📊 ${folder.name}: $recordingCount recordings');
      }

      // Update custom folder recording counts as well
      final updatedCustomFolders = <FolderEntity>[];
      for (final folder in customFolders) {
        final recordingCount = await _recordingStats.getRecordingCountByFolder(folder.id);
        final updatedFolder = folder.copyWith(recordingCount: recordingCount);
        updatedCustomFolders.add(updatedFolder);
        print('📊 ${folder.name}: $recordingCount recordings');
      }

      // Combine updated folders
      final allFolders = [...updatedDefaultFolders, ...updatedCustomFolders];

      print('📂 Total folders: ${allFolders.length} (${updatedDefaultFolders.length} default, ${updatedCustomFolders.length} custom)');

      return allFolders;
    } catch (e) {
      print('❌ Error getting all folders: $e');
      // Return default folders as fallback
      return _getDefaultFolders();
    }
  }

  @override
  Future<List<FolderEntity>> getCustomFolders() async {
    try {
      print('🔍 Querying custom folders from database...');
      final db = await DatabaseHelper.database;

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.foldersTable,
        orderBy: '${DatabaseHelper.folderCreatedAtColumn} DESC',
      );

      print('📊 Database query returned ${maps.length} rows');

      if (maps.isNotEmpty) {
        print('📋 Database rows:');
        for (int i = 0; i < maps.length; i++) {
          print('  Row $i: ${maps[i]}');
        }
      }

      final folders = maps.map((map) => _mapToFolderEntity(map)).toList();

      print('✅ Mapped to ${folders.length} folder entities');
      for (final folder in folders) {
        print('  - ${folder.name} (ID: ${folder.id})');
      }

      return folders;
    } catch (e) {
      print('❌ Error getting custom folders: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  @override
  Future<FolderEntity?> getFolderById(String id) async {
    try {
      print('🔍 Looking for folder with ID: $id');

      // Check if it's a default folder first
      final defaultFolder = _getDefaultFolders()
          .cast<FolderEntity?>()
          .firstWhere((folder) => folder?.id == id, orElse: () => null);

      if (defaultFolder != null) {
        print('✅ Found default folder: ${defaultFolder.name}');
        return defaultFolder;
      }

      // Check custom folders in database
      final db = await DatabaseHelper.database;

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.foldersTable,
        where: '${DatabaseHelper.folderIdColumn} = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final folder = _mapToFolderEntity(maps.first);
        print('✅ Found custom folder: ${folder.name}');
        return folder;
      }

      print('❌ Folder not found with ID: $id');
      return null;
    } catch (e) {
      print('❌ Error getting folder by ID: $e');
      return null;
    }
  }

  @override
  Future<FolderEntity> createFolder(FolderEntity folder) async {
    try {
      print('📝 Creating folder: ${folder.name}');
      final db = await DatabaseHelper.database;

      // Check if folder with same name already exists
      final exists = await folderExistsByName(folder.name);
      if (exists) {
        throw Exception('A folder with the name "${folder.name}" already exists');
      }

      final folderMap = _mapFromFolderEntity(folder);
      print('📊 Folder data to insert: $folderMap');

      await db.insert(
        DatabaseHelper.foldersTable,
        folderMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ Folder inserted into database: ${folder.name}');

      // Verify insertion by querying back
      final verification = await db.query(
        DatabaseHelper.foldersTable,
        where: '${DatabaseHelper.folderIdColumn} = ?',
        whereArgs: [folder.id],
      );

      print('🔍 Verification query returned ${verification.length} rows');
      if (verification.isNotEmpty) {
        print('✅ Folder verified in database: ${verification.first}');
      }

      return folder;
    } catch (e) {
      print('❌ Error creating folder: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  @override
  Future<FolderEntity> updateFolder(FolderEntity folder) async {
    try {
      print('📝 Updating folder: ${folder.name}');
      final db = await DatabaseHelper.database;

      final folderMap = _mapFromFolderEntity(folder);
      folderMap[DatabaseHelper.folderUpdatedAtColumn] = DateTime.now().toIso8601String();

      final rowsAffected = await db.update(
        DatabaseHelper.foldersTable,
        folderMap,
        where: '${DatabaseHelper.folderIdColumn} = ?',
        whereArgs: [folder.id],
      );

      if (rowsAffected == 0) {
        throw Exception('Folder not found for update: ${folder.id}');
      }

      print('✅ Updated folder: ${folder.name} ($rowsAffected rows affected)');
      return folder.copyWith(updatedAt: DateTime.now());
    } catch (e) {
      print('❌ Error updating folder: $e');
      rethrow;
    }
  }

  @override
  Future<bool> deleteFolder(String id) async {
    try {
      print('🗑️ Deleting folder with ID: $id');
      final db = await DatabaseHelper.database;

      // Check if folder exists and is deletable
      final folder = await getFolderById(id);
      if (folder == null) {
        print('❌ Folder not found for deletion: $id');
        return false;
      }

      if (!folder.canBeDeleted) {
        throw Exception('Folder cannot be deleted: ${folder.name}');
      }

      final rowsAffected = await db.delete(
        DatabaseHelper.foldersTable,
        where: '${DatabaseHelper.folderIdColumn} = ?',
        whereArgs: [id],
      );

      if (rowsAffected > 0) {
        print('✅ Deleted folder: ${folder.name} ($rowsAffected rows affected)');
        return true;
      } else {
        print('❌ No rows affected when deleting folder: $id');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting folder: $e');
      return false;
    }
  }

  @override
  Future<bool> folderExistsByName(String name, {String? excludeId}) async {
    try {
      // Check default folders
      final defaultExists = _getDefaultFolders().any(
            (folder) => folder.name.toLowerCase() == name.toLowerCase(),
      );

      if (defaultExists) {
        print('⚠️ Folder name exists in defaults: $name');
        return true;
      }

      // Check custom folders
      final db = await DatabaseHelper.database;

      String whereClause = 'LOWER(${DatabaseHelper.folderNameColumn}) = LOWER(?)';
      List<dynamic> whereArgs = [name];

      if (excludeId != null) {
        whereClause += ' AND ${DatabaseHelper.folderIdColumn} != ?';
        whereArgs.add(excludeId);
      }

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.foldersTable,
        where: whereClause,
        whereArgs: whereArgs,
        limit: 1,
      );

      final exists = maps.isNotEmpty;
      print('🔍 Folder name exists check for "$name": $exists');
      return exists;
    } catch (e) {
      print('❌ Error checking folder existence: $e');
      return false;
    }
  }

  // ==== FOLDER COUNT OPERATIONS ====

  @override
  Future<bool> updateFolderCount(String folderId, int newCount) async {
    try {
      final db = await DatabaseHelper.database;

      final rowsAffected = await db.update(
        DatabaseHelper.foldersTable,
        {
          DatabaseHelper.folderCountColumn: newCount,
          DatabaseHelper.folderUpdatedAtColumn: DateTime.now().toIso8601String(),
        },
        where: '${DatabaseHelper.folderIdColumn} = ?',
        whereArgs: [folderId],
      );

      if (rowsAffected > 0) {
        print('✅ Updated folder count for $folderId: $newCount');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error updating folder count: $e');
      return false;
    }
  }

  @override
  Future<bool> incrementFolderCount(String folderId) async {
    try {
      final db = await DatabaseHelper.database;

      final rowsAffected = await db.rawUpdate(
        '''
        UPDATE ${DatabaseHelper.foldersTable} 
        SET ${DatabaseHelper.folderCountColumn} = ${DatabaseHelper.folderCountColumn} + 1,
            ${DatabaseHelper.folderUpdatedAtColumn} = ?
        WHERE ${DatabaseHelper.folderIdColumn} = ?
      ''',
        [DateTime.now().toIso8601String(), folderId],
      );

      if (rowsAffected > 0) {
        print('✅ Incremented folder count for: $folderId');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error incrementing folder count: $e');
      return false;
    }
  }

  @override
  Future<bool> decrementFolderCount(String folderId) async {
    try {
      final db = await DatabaseHelper.database;

      final rowsAffected = await db.rawUpdate(
        '''
        UPDATE ${DatabaseHelper.foldersTable} 
        SET ${DatabaseHelper.folderCountColumn} = MAX(0, ${DatabaseHelper.folderCountColumn} - 1),
            ${DatabaseHelper.folderUpdatedAtColumn} = ?
        WHERE ${DatabaseHelper.folderIdColumn} = ?
      ''',
        [DateTime.now().toIso8601String(), folderId],
      );

      if (rowsAffected > 0) {
        print('✅ Decremented folder count for: $folderId');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error decrementing folder count: $e');
      return false;
    }
  }

  // ==== BATCH OPERATIONS ====

  @override
  Future<List<FolderEntity>> getFoldersWithRecordings() async {
    try {
      final allFolders = await getAllFolders();
      return allFolders.where((folder) => folder.hasRecordings).toList();
    } catch (e) {
      print('❌ Error getting folders with recordings: $e');
      return [];
    }
  }

  @override
  Future<List<FolderEntity>> getFoldersSorted(FolderSortCriteria criteria) async {
    try {
      final db = await DatabaseHelper.database;

      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.foldersTable,
        orderBy: criteria.sqlOrderBy,
      );

      final customFolders = maps.map((map) => _mapToFolderEntity(map)).toList();

      // Combine with default folders and sort everything
      final allFolders = [..._getDefaultFolders(), ...customFolders];

      // Sort all folders by criteria
      switch (criteria) {
        case FolderSortCriteria.name:
          allFolders.sort(FolderEntity.compareByName);
          break;
        case FolderSortCriteria.createdDate:
          allFolders.sort(FolderEntity.compareByCreatedDate);
          break;
        case FolderSortCriteria.recordingCount:
          allFolders.sort(FolderEntity.compareByRecordingCount);
          break;
        case FolderSortCriteria.lastModified:
          allFolders.sort((a, b) {
            final aUpdated = a.updatedAt ?? a.createdAt;
            final bUpdated = b.updatedAt ?? b.createdAt;
            return bUpdated.compareTo(aUpdated);
          });
          break;
      }

      return allFolders;
    } catch (e) {
      print('❌ Error getting sorted folders: $e');
      return await getAllFolders();
    }
  }

  @override
  Future<List<FolderEntity>> searchFolders(String query) async {
    try {
      final allFolders = await getAllFolders();
      final lowercaseQuery = query.toLowerCase();

      return allFolders
          .where((folder) => folder.name.toLowerCase().contains(lowercaseQuery))
          .toList();
    } catch (e) {
      print('❌ Error searching folders: $e');
      return [];
    }
  }

  // ==== UTILITY OPERATIONS ====

  @override
  Future<int> getTotalRecordingCount() async {
    try {
      final db = await DatabaseHelper.database;

      final result = await db.rawQuery(
        'SELECT SUM(${DatabaseHelper.folderCountColumn}) as total FROM ${DatabaseHelper.foldersTable}',
      );

      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('❌ Error getting total recording count: $e');
      return 0;
    }
  }

  @override
  Future<Map<String, dynamic>> exportFolders() async {
    try {
      final customFolders = await getCustomFolders();

      return {
        'version': 1,
        'export_date': DateTime.now().toIso8601String(),
        'folders': customFolders.map((folder) => folder.toData()).toList(),
      };
    } catch (e) {
      print('❌ Error exporting folders: $e');
      return {};
    }
  }

  @override
  Future<bool> importFolders(Map<String, dynamic> data) async {
    try {
      final foldersData = data['folders'] as List<dynamic>?;
      if (foldersData == null) return false;

      for (final folderData in foldersData) {
        final folder = FolderEntity.fromData(
          id: folderData['id'],
          name: folderData['name'],
          iconCodePoint: folderData['iconCodePoint'],
          colorValue: folderData['colorValue'],
          recordingCount: folderData['recordingCount'],
          type: FolderType.values[folderData['type']],
          isDeletable: folderData['isDeletable'],
          createdAt: DateTime.parse(folderData['createdAt']),
          updatedAt: folderData['updatedAt'] != null
              ? DateTime.parse(folderData['updatedAt'])
              : null,
        );

        await createFolder(folder);
      }

      return true;
    } catch (e) {
      print('❌ Error importing folders: $e');
      return false;
    }
  }

  @override
  Future<bool> clearCustomFolders() async {
    try {
      final db = await DatabaseHelper.database;

      await db.delete(DatabaseHelper.foldersTable);

      print('🧹 Cleared all custom folders');
      return true;
    } catch (e) {
      print('❌ Error clearing custom folders: $e');
      return false;
    }
  }

  // ==== PRIVATE HELPER METHODS ====

  /// Convert database map to FolderEntity
  FolderEntity _mapToFolderEntity(Map<String, dynamic> map) {
    try {
      return FolderEntity.fromData(
        id: map[DatabaseHelper.folderIdColumn],
        name: map[DatabaseHelper.folderNameColumn],
        iconCodePoint: map[DatabaseHelper.folderIconColumn],
        colorValue: map[DatabaseHelper.folderColorColumn],
        recordingCount: map[DatabaseHelper.folderCountColumn],
        type: FolderType.values[map[DatabaseHelper.folderTypeColumn]],
        isDeletable: map[DatabaseHelper.folderIsDeletableColumn] == 1,
        createdAt: DateTime.parse(map[DatabaseHelper.folderCreatedAtColumn]),
        updatedAt: map[DatabaseHelper.folderUpdatedAtColumn] != null
            ? DateTime.parse(map[DatabaseHelper.folderUpdatedAtColumn])
            : null,
      );
    } catch (e) {
      print('❌ Error mapping database row to folder entity: $e');
      print('❌ Problematic row: $map');
      rethrow;
    }
  }

  /// Convert FolderEntity to database map
  Map<String, dynamic> _mapFromFolderEntity(FolderEntity folder) {
    return {
      DatabaseHelper.folderIdColumn: folder.id,
      DatabaseHelper.folderNameColumn: folder.name,
      DatabaseHelper.folderIconColumn: folder.icon.codePoint,
      DatabaseHelper.folderColorColumn: folder.color.value,
      DatabaseHelper.folderCountColumn: folder.recordingCount,
      DatabaseHelper.folderTypeColumn: folder.type.index,
      DatabaseHelper.folderIsDeletableColumn: folder.isDeletable ? 1 : 0,
      DatabaseHelper.folderCreatedAtColumn: folder.createdAt.toIso8601String(),
      DatabaseHelper.folderUpdatedAtColumn: folder.updatedAt?.toIso8601String(),
    };
  }
}
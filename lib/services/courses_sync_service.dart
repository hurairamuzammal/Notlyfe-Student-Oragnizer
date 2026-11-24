import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/database/courses_database.dart';
import 'package:notlyfe/database/local/courses_local_database.dart';
import 'package:notlyfe/models/course.dart';
import 'package:notlyfe/providers/connection_status_provider.dart';

final coursesSyncServiceProvider = Provider<CoursesSyncService>((ref) {
  final localDb = ref.watch(coursesLocalDatabaseProvider);
  final service = CoursesSyncService(
    localDb,
    CoursesDatabase(),
    ref.read(networkServiceProvider),
  );

  ref.listen<bool>(networkServiceProvider, (previous, current) {
    service.updateConnectivityStatus(current);
    if (previous == false && current == true) {
      final userId = service.getCurrentUserId();
      if (userId != null) {
        unawaited(service.syncAll(userId));
      }
    }
  });

  return service;
});

final autoSyncCoursesProvider = Provider<AutoSyncCoursesService>((ref) {
  return AutoSyncCoursesService(ref.watch(coursesSyncServiceProvider));
});

class AutoSyncCoursesService {
  final CoursesSyncService _syncService;
  AutoSyncCoursesService(this._syncService);
  CoursesSyncService get service => _syncService;
}

/// Offline-first sync layer between local SQLite courses and Supabase.
class CoursesSyncService {
  final CoursesLocalDatabase _localDb;
  final CoursesDatabase _supabaseDb;
  bool _isConnected;

  CoursesSyncService(this._localDb, this._supabaseDb, this._isConnected);

  void updateConnectivityStatus(bool isConnected) {
    _isConnected = isConnected;
  }

  bool get isConnected => _isConnected;

  String? getCurrentUserId() {
    try {
      return _supabaseDb.client.auth.currentUser?.id;
    } catch (e) {
      debugPrint('Error getting current user ID: $e');
      return null;
    }
  }

  Future<List<Course>> getCourses(String userId) async {
    try {
      final localCourses = await _localDb.getCourses(userId);
      if (!_isConnected || userId == 'local_user') return localCourses;

      try {
        final cloudCourses = await _supabaseDb.getCourses(userId);
        await _localDb.saveCoursesFromCloud(cloudCourses);
        return await _localDb.getCourses(userId);
      } catch (e) {
        debugPrint('Courses cloud sync fallback: $e');
        return localCourses;
      }
    } catch (e) {
      debugPrint('Error getting courses: $e');
      return [];
    }
  }

  Future<Course> createCourse(Course course) async {
    await _localDb.createCourse(course);
    if (_isConnected && course.user_id != 'local_user') {
      try {
        await _supabaseDb.addCourse(course);
        await _localDb.markCourseSynced(course.id);
      } catch (e) {
        debugPrint('Error syncing new course: $e');
      }
    }
    return course;
  }

  Future<Course> updateCourse(Course course) async {
    await _localDb.updateCourse(course);
    if (_isConnected && course.user_id != 'local_user') {
      try {
        await _supabaseDb.updateCourse(course);
        await _localDb.markCourseSynced(course.id);
      } catch (e) {
        debugPrint('Error syncing updated course: $e');
      }
    }
    return course;
  }

  Future<void> deleteCourse(Course course) async {
    await _localDb.deleteCourse(course.id);
    if (_isConnected && course.user_id != 'local_user') {
      try {
        await _supabaseDb.deleteCourse(course);
      } catch (e) {
        debugPrint('Error deleting course remotely: $e');
      }
    }
  }

  Future<void> _syncCourses(String userId) async {
    if (!_isConnected || userId == 'local_user') return;
    try {
      final unsyncedCourses = await _localDb.getUnsyncedCourses(userId);
      for (final course in unsyncedCourses) {
        try {
          await _supabaseDb.updateCourse(course);
          await _localDb.markCourseSynced(course.id);
        } catch (_) {
          try {
            await _supabaseDb.addCourse(course);
            await _localDb.markCourseSynced(course.id);
          } catch (e) {
            debugPrint('Failed pushing unsynced course ${course.id}: $e');
          }
        }
      }

      final cloudCourses = await _supabaseDb.getCourses(userId);
      if (cloudCourses.isNotEmpty) {
        await _localDb.saveCoursesFromCloud(cloudCourses);
      }
    } catch (e) {
      debugPrint('Error during full courses sync: $e');
    }
  }

  Future<void> syncAll(String userId) async {
    if (_isConnected) {
      await _syncCourses(userId);
    }
  }
}

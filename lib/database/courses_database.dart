import 'package:flutter/foundation.dart';
import 'package:notlyfe/models/course.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote CRUD operations for the `courses` table in Supabase.
class CoursesDatabase {
  SupabaseClient get client => Supabase.instance.client;
  SupabaseQueryBuilder get _coursesTable => client.from('courses');

  Future<void> addCourse(Course newCourse) async {
    try {
      await _coursesTable.insert(newCourse.toSupabaseMap());
    } catch (e) {
      debugPrint('Error adding course: $e');
      rethrow;
    }
  }

  Future<void> updateCourse(Course updatedCourse) async {
    try {
      await _coursesTable
          .update(updatedCourse.toSupabaseMap())
          .eq('id', updatedCourse.id)
          .eq('user_id', updatedCourse.user_id);
    } catch (e) {
      debugPrint('Error updating course: $e');
      rethrow;
    }
  }

  Future<void> deleteCourse(Course course) async {
    try {
      await _coursesTable
          .delete()
          .eq('id', course.id)
          .eq('user_id', course.user_id);
    } catch (e) {
      debugPrint('Error deleting course: $e');
      rethrow;
    }
  }

  Future<List<Course>> getCourses(String userId) async {
    try {
      final response = await _coursesTable.select().eq('user_id', userId);
      return response.map((courseMap) => Course.fromMap(courseMap)).toList();
    } catch (e) {
      debugPrint('Error fetching courses: $e');
      return [];
    }
  }
}

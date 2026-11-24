import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/models/course.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/services/courses_sync_service.dart';

// Provider for all courses
final coursesProvider = FutureProvider<List<Course>>((ref) async {
  final syncService = ref.watch(coursesSyncServiceProvider);
  final authService = AuthServices();
  final userId = authService.getCurrentUserId();
  return await syncService.getCourses(userId);
});

// Provider for a specific course
final courseProvider =
    FutureProvider.family<Course?, String>((ref, courseId) async {
  final coursesList = await ref.watch(coursesProvider.future);
  try {
    return coursesList.firstWhere((course) => course.id == courseId);
  } catch (e) {
    return null;
  }
});

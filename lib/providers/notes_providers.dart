import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/providers/notes_sync_provider.dart';

// Enum for note sorting options
enum NoteSortOption {
  updatedDesc, // Most recent first (default)
  updatedAsc, // Oldest first
  createdDesc, // Most recently created first
  createdAsc, // Oldest created first
  titleAsc, // Alphabetical (A-Z)
  titleDesc, // Reverse alphabetical (Z-A)
}

// Provider to store the current sort option
final noteSortOptionProvider = StateProvider<NoteSortOption>(
  (ref) => NoteSortOption.updatedDesc,
);

// Provider for all notes
final notesProvider = FutureProvider<List<Note>>((ref) async {
  final syncService = ref.watch(notesSyncServiceProvider);
  final authService = AuthServices();
  final userId = authService.getCurrentUserId();
  final sortOption = ref.watch(noteSortOptionProvider);
  return await syncService.getNotes(userId, sortOption: sortOption);
});

// Provider for notes filtered by course
final courseNotesProvider =
    FutureProvider.family<List<Note>, String>((ref, courseId) async {
  final syncService = ref.watch(notesSyncServiceProvider);
  final authService = AuthServices();
  final userId = authService.getCurrentUserId();
  final sortOption = ref.watch(noteSortOptionProvider);
  return await syncService.getNotesByCourse(userId, courseId,
      sortOption: sortOption);
});

// Provider for a specific note
final noteProvider = FutureProvider.family<Note?, String>((ref, noteId) async {
  final notesList = await ref.watch(notesProvider.future);
  try {
    return notesList.firstWhere((note) => note.id == noteId);
  } catch (e) {
    return null;
  }
});

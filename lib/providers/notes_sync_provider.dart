import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/database/local/notes_local_database.dart';
import 'package:notlyfe/providers/connection_status_provider.dart';
import 'package:notlyfe/services/notes_sync_service.dart';
import 'package:notlyfe/services/storage/storage_provider.dart';

export 'package:notlyfe/services/notes_sync_service.dart';

final notesSyncServiceProvider = Provider<NotesSyncService>((ref) {
  final localDb = ref.watch(notesLocalDatabaseProvider);
  final registry = ref.watch(storageRegistryProvider);
  final service = NotesSyncService(
    localDb,
    ref.read(networkServiceProvider),
    registry: registry,
  );

  // Keep connectivity in sync without tearing down the service on toggles.
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

final autoSyncNotesProvider = Provider<AutoSyncNotesService>((ref) {
  return AutoSyncNotesService(ref.watch(notesSyncServiceProvider));
});

class AutoSyncNotesService {
  final NotesSyncService _syncService;
  AutoSyncNotesService(this._syncService);
  NotesSyncService get service => _syncService;
}

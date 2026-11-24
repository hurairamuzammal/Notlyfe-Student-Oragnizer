import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/models/todo.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/services/todos_sync_service.dart';
import 'package:notlyfe/widgets/todo_edit_dialog.dart';
import 'package:notlyfe/widgets/todo_list_widget.dart';

class DraggableSheet extends ConsumerStatefulWidget {
  const DraggableSheet({
    super.key,
  });

  static List<Todo> todos = [];

  static final ValueNotifier<List<Todo>> todosNotifier =
      ValueNotifier<List<Todo>>([]);

  static final DraggableScrollableController sheetController =
      DraggableScrollableController();

  static void expand() {
    if (sheetController.isAttached) {
      sheetController.animateTo(
        0.88,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  static void collapse() {
    if (sheetController.isAttached) {
      sheetController.animateTo(
        0.13,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  static void updateTodos(List<Todo> newTodos) {
    todos = newTodos;
    todosNotifier.value = List.from(newTodos);
  }

  /// Clears in-memory tasks on sign-out to prevent leaking data across accounts.
  static void clearTodos() {
    todos = [];
    todosNotifier.value = const [];
  }

  @override
  ConsumerState<DraggableSheet> createState() => _DraggableSheetState();
}

class _DraggableSheetState extends ConsumerState<DraggableSheet> {
  final authInstance = AuthServices();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    loadTodos();
    DraggableSheet.todosNotifier.addListener(_onTodosChanged);
  }

  @override
  void dispose() {
    DraggableSheet.todosNotifier.removeListener(_onTodosChanged);
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTodosChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> addNewTodo() async {
    final result = await TodoEditModal.show(context);
    if (result == null || !mounted) return;

    final newTodo = Todo(
      id: DateTime.now().millisecondsSinceEpoch,
      user_id: authInstance.getCurrentUserId(),
      content: result.content,
      reminder_at: result.reminderAt,
      created_at: DateTime.now(),
      alert: result.alert,
    );

    final autoSyncService = ref.read(autoSyncTodosProvider);
    await autoSyncService.service.createTodo(newTodo);
    loadTodos();
  }

  Future<void> showEditDialogBox(Todo todo) async {
    final originalId = todo.id;
    if (originalId == null) return;
    final result = await TodoEditModal.show(context, existingTodo: todo);
    if (result == null || !mounted) return;

    if (originalId != todo.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Todo ID mismatch. Update failed.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    todo.content = result.content;
    todo.alert = result.alert;
    todo.reminder_at = result.reminderAt;

    final autoSyncService = ref.read(autoSyncTodosProvider);
    await autoSyncService.service.updateTodo(todo);
    loadTodos();
  }

  Future<void> loadTodos() async {
    if (!mounted) return;
    try {
      final userId = authInstance.getCurrentUserId();
      final autoSyncService = ref.read(autoSyncTodosProvider);
      final retrievedTodos = await autoSyncService.service.getTodos(userId);
      DraggableSheet.updateTodos(retrievedTodos);
    } catch (e) {
      debugPrint('Error loading todos: $e');
    }
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = DraggableSheet.todos.removeAt(oldIndex);
      DraggableSheet.todos.insert(newIndex, item);
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      loadTodos();
    });
  }

  void onStatusChanged(Todo todo, bool? value) {
    setState(() {
      todo.status = value ?? false;
    });

    final autoSyncService = ref.read(autoSyncTodosProvider);
    autoSyncService.service.changeStatus(todo).then((_) {
      loadTodos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<List<Todo>>(
      valueListenable: DraggableSheet.todosNotifier,
      builder: (context, todos, _) {
        return DraggableScrollableSheet(
          controller: DraggableSheet.sheetController,
          initialChildSize: 0.13,
          minChildSize: 0.13,
          snap: true,
          snapAnimationDuration: const Duration(milliseconds: 220),
          maxChildSize: 1.0,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.15),
                    spreadRadius: 2,
                    blurRadius: 14,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.checklist_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'To-Do',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    Text(
                                      todos.isEmpty
                                          ? 'No pending tasks'
                                          : '${todos.where((t) => t.status).length} of ${todos.length} done',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                ),
                                onPressed: addNewTodo,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text(
                                  'Add Task',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  TodoListWidget(
                    todos: todos,
                    onEdit: showEditDialogBox,
                    onDelete: (todo) async {
                      final autoSyncService = ref.read(autoSyncTodosProvider);
                      await autoSyncService.service.deleteTodo(todo);
                      await loadTodos();
                    },
                    onStatusChanged: onStatusChanged,
                    onReorder: _handleReorder,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

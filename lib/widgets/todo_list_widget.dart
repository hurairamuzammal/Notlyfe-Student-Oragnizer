import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notlyfe/models/todo.dart';
import 'package:notlyfe/widgets/glitter_tap.dart';

class TodoListWidget extends StatelessWidget {
  final List<Todo> todos;
  final Function(Todo) onEdit;
  final Function(Todo) onDelete;
  final Function(Todo, bool?) onStatusChanged;
  final Function(int, int) onReorder;

  const TodoListWidget({
    super.key,
    required this.todos,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (todos.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.task_alt_rounded,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No Tasks Yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "Add Task" to create a new reminder',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final incompleteTodos = todos.where((todo) => !todo.status).toList();
    final completedTodos = todos.where((todo) => todo.status).toList();

    return SliverList(
      delegate: SliverChildListDelegate([
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                child: child,
              ),
            );
          },
          child: incompleteTodos.isEmpty
              ? Padding(
                  key: const ValueKey('empty-state'),
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Center(
                    child: Text(
                      'All caught up! Add a new task anytime.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                )
              : Column(
                  key: const ValueKey('incomplete-todos'),
                  children: incompleteTodos
                      .asMap()
                      .entries
                      .map((entry) => _buildAnimatedTodoItem(
                          context, entry.value, entry.key))
                      .toList(),
                ),
        ),
        if (completedTodos.isNotEmpty)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            opacity: 1.0,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'COMPLETED (${completedTodos.length})',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
                ...completedTodos.asMap().entries.map((entry) =>
                    _buildAnimatedTodoItem(context, entry.value,
                        entry.key + incompleteTodos.length)),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildAnimatedTodoItem(BuildContext context, Todo todo, [int? index]) {
    return AnimatedOpacity(
      key: ValueKey(todo.id),
      duration: const Duration(milliseconds: 260),
      opacity: 1.0,
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 240 + (index ?? 0) * 60),
        tween: Tween<double>(begin: 0, end: 1),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Hero(
          tag: 'todo-${todo.id}',
          child: _buildTodoItem(context, todo),
        ),
      ),
    );
  }

  Widget _buildTodoItem(BuildContext context, Todo todo) {
    final theme = Theme.of(context);
    final hasReminder = todo.alert && todo.reminder_at != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlitterTap(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onEdit(todo),
        child: Container(
          decoration: BoxDecoration(
            color: todo.status
                ? theme.colorScheme.surfaceContainerLowest
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _buildAnimatedCheckbox(todo),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: todo.status ? FontWeight.w500 : FontWeight.w600,
                        letterSpacing: -0.1,
                        decoration: todo.status ? TextDecoration.lineThrough : null,
                        color: todo.status
                            ? theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5)
                            : theme.colorScheme.onSurface,
                      ),
                      child: Text(todo.content),
                    ),
                    if (hasReminder)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: todo.status
                                    ? theme.colorScheme.surfaceContainerHighest
                                    : theme.colorScheme.primaryContainer
                                        .withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.alarm_rounded,
                                    size: 11,
                                    color: todo.status
                                        ? theme.colorScheme.onSurfaceVariant
                                        : theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('MMM d • h:mm a')
                                        .format(todo.reminder_at!),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: todo.status
                                          ? theme.colorScheme.onSurfaceVariant
                                          : theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: theme.colorScheme.error.withValues(alpha: 0.7),
                ),
                onPressed: () => onDelete(todo),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCheckbox(Todo todo) {
    return Checkbox(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      value: todo.status,
      onChanged: (bool? newValue) {
        Future.delayed(const Duration(milliseconds: 160), () {
          onStatusChanged(todo, newValue);
        });
      },
    );
  }
}

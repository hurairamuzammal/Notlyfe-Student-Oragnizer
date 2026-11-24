import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:notlyfe/models/todo.dart';
import 'package:notlyfe/widgets/glitter_tap.dart';

class TodoEditResult {
  final String content;
  final bool alert;
  final DateTime? reminderAt;

  const TodoEditResult({
    required this.content,
    required this.alert,
    this.reminderAt,
  });
}

class TodoEditModal extends StatefulWidget {
  final Todo? existingTodo;

  const TodoEditModal({
    super.key,
    this.existingTodo,
  });

  static Future<TodoEditResult?> show(
    BuildContext context, {
    Todo? existingTodo,
  }) {
    return showModalBottomSheet<TodoEditResult>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TodoEditModal(existingTodo: existingTodo),
    );
  }

  @override
  State<TodoEditModal> createState() => _TodoEditModalState();
}

class _TodoEditModalState extends State<TodoEditModal> {
  late TextEditingController _contentController;
  late bool _alertEnabled;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    final todo = widget.existingTodo;
    _contentController = TextEditingController(text: todo?.content ?? '');
    _alertEnabled = todo?.alert ?? false;

    final defaultReminder = DateTime.now().add(const Duration(hours: 1));
    final initialDateTime = todo?.reminder_at ?? defaultReminder;
    _selectedDate = DateTime(
      initialDateTime.year,
      initialDateTime.month,
      initialDateTime.day,
    );
    _selectedTime = TimeOfDay.fromDateTime(initialDateTime);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  DateTime get _combinedDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  void _applyPreset(DateTime target) {
    setState(() {
      _alertEnabled = true;
      _selectedDate = DateTime(target.year, target.month, target.day);
      _selectedTime = TimeOfDay.fromDateTime(target);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(DateTime(2020)) ? now : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submit() {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task description')),
      );
      return;
    }

    Navigator.of(context).pop(
      TodoEditResult(
        content: text,
        alert: _alertEnabled,
        reminderAt: _alertEnabled ? _combinedDateTime : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingTodo != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final formattedDate = DateFormat('EEE, MMM d').format(_selectedDate);
    final formattedTime = _selectedTime.format(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: 18,
        right: 18,
        bottom: bottomInset > 0 ? bottomInset + 14 : 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Minimal Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.add_task_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isEditing ? 'Edit Task' : 'New Task',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 10,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'E2EE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Set what to do and optional reminder',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Task Content Input
            TextField(
              controller: _contentController,
              autofocus: !isEditing,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'What needs to be done?',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Simplified Reminder Toggle Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _alertEnabled ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
                        size: 18,
                        color: _alertEnabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _alertEnabled ? '$formattedDate • $formattedTime' : 'No Reminder Set',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _alertEnabled ? FontWeight.w700 : FontWeight.w500,
                            color: _alertEnabled
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      Switch(
                        value: _alertEnabled,
                        onChanged: (val) => setState(() => _alertEnabled = val),
                      ),
                    ],
                  ),
                  if (_alertEnabled) ...[
                    const Divider(height: 8),
                    // Quick Presets Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildPresetChip(
                            theme,
                            label: 'Today 8 PM',
                            onTap: () {
                              final now = DateTime.now();
                              _applyPreset(DateTime(now.year, now.month, now.day, 20, 0));
                            },
                          ),
                          const SizedBox(width: 6),
                          _buildPresetChip(
                            theme,
                            label: 'Tomorrow 9 AM',
                            onTap: () {
                              final tom = DateTime.now().add(const Duration(days: 1));
                              _applyPreset(DateTime(tom.year, tom.month, tom.day, 9, 0));
                            },
                          ),
                          const SizedBox(width: 6),
                          _buildPresetChip(
                            theme,
                            label: 'Custom Date',
                            onTap: _pickDate,
                          ),
                          const SizedBox(width: 6),
                          _buildPresetChip(
                            theme,
                            label: 'Custom Time',
                            onTap: _pickTime,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons with Glitter Ripple
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GlitterTap(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: GlitterTap(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isEditing ? Icons.check_circle_rounded : Icons.add_rounded,
                            size: 18,
                            color: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isEditing ? 'Save' : 'Add Task',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(
    ThemeData theme, {
    required String label,
    required VoidCallback onTap,
  }) {
    return GlitterTap(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:notlyfe/database/calander_database.dart';
import 'package:notlyfe/models/todo.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/services/e2ee_service.dart';
import 'package:notlyfe/services/todos_sync_service.dart';
import 'package:notlyfe/widgets/glitter_tap.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';
import 'package:notlyfe/widgets/todo_edit_dialog.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class CalenderScreen extends ConsumerStatefulWidget {
  const CalenderScreen({super.key});

  @override
  ConsumerState<CalenderScreen> createState() => _CalenderScreenState();
}

class _CalenderScreenState extends ConsumerState<CalenderScreen> {
  final CalanderDatabase _calanderDb = CalanderDatabase();
  final CalendarController _calendarController = CalendarController();

  List<Meeting> _meetings = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  CalendarView _currentView = CalendarView.month;

  @override
  void initState() {
    super.initState();
    _calendarController.view = CalendarView.month;
    _calendarController.selectedDate = _selectedDate;
    _fetchEvents();
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      final response = await _calanderDb.getEvents();
      final meetings = <Meeting>[];

      for (var todo in response) {
        if (todo['reminder_at'] == null) continue;
        DateTime reminderAt;
        try {
          reminderAt = DateTime.parse(todo['reminder_at']);
        } catch (_) {
          continue;
        }

        final isDone = todo['status'] == true;
        final isAlert = todo['alert'] == true;
        final rawContent = todo['content']?.toString() ?? 'Untitled Task';
        final decryptedContent = E2eeService.instance.decrypt(rawContent);

        meetings.add(
          Meeting(
            decryptedContent,
            reminderAt,
            reminderAt.add(const Duration(hours: 1)),
            isDone
                ? Colors.grey
                : (isAlert ? Colors.orangeAccent.shade700 : Colors.blueAccent),
            false,
            id: todo['id']?.toString() ?? '',
            isCompleted: isDone,
            hasAlert: isAlert,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _meetings = meetings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onCalendarTap(CalendarTapDetails details) {
    if (details.date != null) {
      setState(() {
        _selectedDate = details.date!;
      });
    }
  }

  void _changeView(CalendarView view) {
    setState(() {
      _currentView = view;
      _calendarController.view = view;
    });
  }

  List<Meeting> _getMeetingsForSelectedDate() {
    return _meetings.where((m) {
      return m.from.year == _selectedDate.year &&
          m.from.month == _selectedDate.month &&
          m.from.day == _selectedDate.day;
    }).toList();
  }

  Future<void> _addNewTaskForSelectedDay() async {
    final result = await TodoEditModal.show(context);
    if (result == null || !mounted) return;

    final authInstance = AuthServices();
    final newTodo = Todo(
      id: DateTime.now().millisecondsSinceEpoch,
      user_id: authInstance.getCurrentUserId(),
      content: result.content,
      reminder_at: result.reminderAt ??
          DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            9,
            0,
          ),
      created_at: DateTime.now(),
      alert: result.alert,
    );

    final autoSyncService = ref.read(autoSyncTodosProvider);
    await autoSyncService.service.createTodo(newTodo);
    _fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedDayMeetings = _getMeetingsForSelectedDate();
    final dateFormatted = DateFormat('EEEE, MMM d').format(_selectedDate);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calendar & Deadlines',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Scheduled tasks & reminders',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: _isLoading
                ? const M3ShapeChangingProgressIndicator(size: 20, strokeWidth: 2)
                : const Icon(Icons.refresh_rounded, size: 21),
            tooltip: 'Refresh events',
            onPressed: _isLoading ? null : _fetchEvents,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // View Switcher Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildViewChip('Month', CalendarView.month),
                const SizedBox(width: 6),
                _buildViewChip('Week', CalendarView.week),
                const SizedBox(width: 6),
                _buildViewChip('Day', CalendarView.day),
                const SizedBox(width: 6),
                _buildViewChip('Agenda', CalendarView.schedule),
              ],
            ),
          ),

          // Main Calendar Card
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: SfCalendar(
                  controller: _calendarController,
                  view: _currentView,
                  initialSelectedDate: _selectedDate,
                  dataSource: MeetingDataSource(_meetings),
                  onTap: _onCalendarTap,
                  backgroundColor: Colors.transparent,
                  headerHeight: 46,
                  headerStyle: CalendarHeaderStyle(
                    backgroundColor: Colors.transparent,
                    textStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  viewHeaderStyle: ViewHeaderStyle(
                    dayTextStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                    dateTextStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  todayHighlightColor: theme.colorScheme.primary,
                  selectionDecoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  monthViewSettings: const MonthViewSettings(
                    appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
                    showAgenda: false,
                  ),
                  appointmentTextStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  showNavigationArrow: true,
                  firstDayOfWeek: 1,
                  showTodayButton: true,
                ),
              ),
            ),
          ),

          // Selected Day Agenda Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_note_rounded, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      dateFormatted.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                GlitterTap(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _addNewTaskForSelectedDay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Add Task',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Selected Day Tasks List
          Expanded(
            flex: 3,
            child: selectedDayMeetings.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            size: 32,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No reminders on this date',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: selectedDayMeetings.length,
                    itemBuilder: (context, index) {
                      final item = selectedDayMeetings[index];
                      final timeStr = DateFormat('h:mm a').format(item.from);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: item.background,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.eventName,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                  color: item.isCompleted
                                      ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildViewChip(String label, CalendarView view) {
    final theme = Theme.of(context);
    final isSelected = _currentView == view;

    return GlitterTap(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _changeView(view),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Meeting> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) => _getMeetingData(index).from;

  @override
  DateTime getEndTime(int index) => _getMeetingData(index).to;

  @override
  String getSubject(int index) => _getMeetingData(index).eventName;

  @override
  Color getColor(int index) => _getMeetingData(index).background;

  @override
  bool isAllDay(int index) => _getMeetingData(index).isAllDay;

  Meeting _getMeetingData(int index) {
    final dynamic meeting = appointments![index];
    if (meeting is Meeting) return meeting;
    return Meeting('Task', DateTime.now(), DateTime.now(), Colors.blue, false);
  }
}

class Meeting {
  String eventName;
  DateTime from;
  DateTime to;
  Color background;
  bool isAllDay;
  String id;
  bool isCompleted;
  bool hasAlert;

  Meeting(
    this.eventName,
    this.from,
    this.to,
    this.background,
    this.isAllDay, {
    this.id = '',
    this.isCompleted = false,
    this.hasAlert = false,
  });
}

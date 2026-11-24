import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notlyfe/widgets/glitter_tap.dart';

class CalculateCgpa extends StatefulWidget {
  const CalculateCgpa({super.key});

  @override
  State<CalculateCgpa> createState() => _CalculateCgpaState();
}

class _CalculateCgpaState extends State<CalculateCgpa> {
  final _formKey = GlobalKey<FormState>();
  final List<CourseGradeItem> _courses = [];

  bool _includePrevious = false;
  final TextEditingController _previousCgpaController = TextEditingController();
  final TextEditingController _previousCreditsController = TextEditingController();

  double? _semesterGpa;
  double? _cumulativeGpa;
  int _totalSemesterCredits = 0;
  double _totalSemesterPoints = 0;

  @override
  void initState() {
    super.initState();
    // Default with 4 courses for a convenient start
    _courses.add(CourseGradeItem(name: 'Course 1', credits: 3, grade: 'A'));
    _courses.add(CourseGradeItem(name: 'Course 2', credits: 3, grade: 'B+'));
    _courses.add(CourseGradeItem(name: 'Course 3', credits: 4, grade: 'A-'));
    _courses.add(CourseGradeItem(name: 'Course 4', credits: 3, grade: 'B'));
  }

  @override
  void dispose() {
    _previousCgpaController.dispose();
    _previousCreditsController.dispose();
    super.dispose();
  }

  void _addCourse() {
    HapticFeedback.selectionClick();
    setState(() {
      _courses.add(
        CourseGradeItem(
          name: 'Course ${_courses.length + 1}',
          credits: 3,
          grade: 'A',
        ),
      );
    });
  }

  void _removeCourse(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _courses.removeAt(index);
      if (_semesterGpa != null) {
        _calculate();
      }
    });
  }

  double _getGradePoints(String grade) {
    switch (grade.toUpperCase()) {
      case 'A+':
        return 4.0;
      case 'A':
        return 4.0;
      case 'A-':
        return 3.7;
      case 'B+':
        return 3.3;
      case 'B':
        return 3.0;
      case 'B-':
        return 2.7;
      case 'C+':
        return 2.3;
      case 'C':
        return 2.0;
      case 'C-':
        return 1.7;
      case 'D':
        return 1.0;
      case 'F':
        return 0.0;
      default:
        return 0.0;
    }
  }

  void _calculate() {
    if (_courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one course!')),
      );
      return;
    }

    double semPoints = 0;
    int semCredits = 0;

    for (var c in _courses) {
      semPoints += c.credits * _getGradePoints(c.grade);
      semCredits += c.credits;
    }

    if (semCredits == 0) return;

    double semGpa = semPoints / semCredits;
    double? cumGpa;

    if (_includePrevious) {
      final prevCgpa = double.tryParse(_previousCgpaController.text.trim());
      final prevCredits = int.tryParse(_previousCreditsController.text.trim());

      if (prevCgpa != null && prevCredits != null && prevCredits > 0) {
        final totalPoints = (prevCgpa * prevCredits) + semPoints;
        final totalCredits = prevCredits + semCredits;
        cumGpa = totalPoints / totalCredits;
      }
    }

    setState(() {
      _totalSemesterCredits = semCredits;
      _totalSemesterPoints = semPoints;
      _semesterGpa = semGpa;
      _cumulativeGpa = cumGpa;
    });

    HapticFeedback.mediumImpact();
  }

  void _reset() {
    setState(() {
      _courses.clear();
      _courses.add(CourseGradeItem(name: 'Course 1', credits: 3, grade: 'A'));
      _courses.add(CourseGradeItem(name: 'Course 2', credits: 3, grade: 'B+'));
      _semesterGpa = null;
      _cumulativeGpa = null;
      _previousCgpaController.clear();
      _previousCreditsController.clear();
    });
  }

  Color _getGpaColor(double gpa) {
    if (gpa >= 3.65) return const Color(0xFF10B981); // Emerald
    if (gpa >= 3.25) return const Color(0xFF0D9488); // Teal
    if (gpa >= 2.95) return const Color(0xFF3B82F6); // Blue
    if (gpa >= 2.45) return const Color(0xFFF59E0B); // Amber
    if (gpa >= 2.00) return const Color(0xFFF97316); // Orange
    return const Color(0xFFEF4444); // Red
  }

  String _getGpaHonors(double gpa) {
    if (gpa >= 3.75) return 'First Class Honours / High Distinction';
    if (gpa >= 3.40) return 'Upper Second Class / Distinction';
    if (gpa >= 3.00) return 'Lower Second Class / Good Standing';
    if (gpa >= 2.50) return 'Third Class / Satisfactory';
    if (gpa >= 2.00) return 'Passing Grade';
    return 'Academic Probation Warning';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeGpa = _cumulativeGpa ?? _semesterGpa;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.transparent),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CGPA Calculator',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Estimate semester & cumulative GPA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 21),
            tooltip: 'Reset',
            onPressed: _reset,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Top GPA Animated Score Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: activeGpa != null
                    ? _getGpaColor(activeGpa).withValues(alpha: 0.12)
                    : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: activeGpa != null
                      ? _getGpaColor(activeGpa).withValues(alpha: 0.45)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: activeGpa != null ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _cumulativeGpa != null ? 'CUMULATIVE CGPA' : 'SEMESTER GPA',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: activeGpa != null
                              ? _getGpaColor(activeGpa)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (activeGpa != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getGpaColor(activeGpa).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            activeGpa >= 3.5 ? 'EXCELLENT' : 'CALCULATED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: _getGpaColor(activeGpa),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Animated GPA Value Counter
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0.0, end: activeGpa ?? 0.0),
                    builder: (context, val, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            activeGpa != null ? val.toStringAsFixed(2) : '0.00',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                              color: activeGpa != null
                                  ? _getGpaColor(activeGpa)
                                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/ 4.00',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  if (activeGpa != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _getGpaHonors(activeGpa),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getGpaColor(activeGpa),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Metrics Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetric(
                        theme,
                        label: 'Courses',
                        value: '${_courses.length}',
                      ),
                      _buildMetric(
                        theme,
                        label: 'Sem Credits',
                        value: '$_totalSemesterCredits',
                      ),
                      _buildMetric(
                        theme,
                        label: 'Quality Pts',
                        value: _totalSemesterPoints.toStringAsFixed(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Prior Academic Record Collapsible Card
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: _includePrevious,
                  onExpansionChanged: (val) => setState(() => _includePrevious = val),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  leading: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.history_edu_rounded, size: 19, color: theme.colorScheme.primary),
                  ),
                  title: const Text(
                    'Include Past Semesters (Cumulative)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _includePrevious
                        ? 'Combining previous CGPA with current semester'
                        : 'Tap to factor in prior completed credits',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _previousCgpaController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                labelText: 'Past CGPA',
                                hintText: 'e.g. 3.45',
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _previousCreditsController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                labelText: 'Past Credits',
                                hintText: 'e.g. 48',
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Course List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ENROLLED COURSES (${_courses.length})',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ),
                GlitterTap(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _addCourse,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Add Course',
                          style: TextStyle(
                            fontSize: 12,
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
            const SizedBox(height: 10),

            // Courses List
            ..._courses.asMap().entries.map((entry) {
              final index = entry.key;
              final course = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: course.name,
                            onChanged: (val) => course.name = val,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Course name or code',
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        // Credits Stepper
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GlitterTap(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                if (course.credits > 1) {
                                  setState(() => course.credits--);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.remove_rounded, size: 14),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${course.credits} Cr',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                            GlitterTap(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                if (course.credits < 10) {
                                  setState(() => course.credits++);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add_rounded, size: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: theme.colorScheme.error.withValues(alpha: 0.75),
                          ),
                          onPressed: () => _removeCourse(index),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Grade Chips Selector
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          'A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D', 'F',
                        ].map((grade) {
                          final isSelected = course.grade.toUpperCase() == grade;
                          final pts = _getGradePoints(grade);
                          final color = _getGpaColor(pts);

                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GlitterTap(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => course.grade = grade),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color
                                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? color : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  '$grade (${pts.toStringAsFixed(1)})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),

            // Big Calculate CGPA Button with Glitter Ripple
            GlitterTap(
              borderRadius: BorderRadius.circular(24),
              onTap: _calculate,
              enableGlitterBurst: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calculate_rounded, size: 20, color: theme.colorScheme.onPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Calculate CGPA',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(ThemeData theme, {required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

class CourseGradeItem {
  String name;
  int credits;
  String grade;

  CourseGradeItem({
    required this.name,
    required this.credits,
    required this.grade,
  });
}

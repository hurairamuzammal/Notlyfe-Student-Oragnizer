import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notlyfe/providers/login_user_provider.dart';
import 'package:notlyfe/screens/ai_chat.dart';
import 'package:notlyfe/screens/all_courses_screen.dart';
import 'package:notlyfe/screens/all_files.dart';
import 'package:notlyfe/screens/calculate_cgpa.dart';
import 'package:notlyfe/screens/calender.dart';
import 'package:notlyfe/screens/download_screen.dart';
import 'package:notlyfe/screens/dragable_sheet.dart';
import 'package:notlyfe/screens/notes_screen.dart';
import 'package:notlyfe/screens/profile.dart';
import 'package:notlyfe/screens/setting.dart';
import 'package:notlyfe/services/auth_gate.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/widgets/glitter_tap.dart';
import 'package:notlyfe/widgets/m3_expressive_widgets.dart';

class DrawerScreen extends ConsumerWidget {
  const DrawerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider);
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            // Material 3 Expressive Profile Hero Card (Identical to Settings header)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.75),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ProfilePage(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: theme.colorScheme.primary,
                          child: Text(
                            (userName.isNotEmpty ? userName[0] : 'U').toUpperCase(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                userName.isNotEmpty ? userName : 'Notlyfe User',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Tap to view profile',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.75),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.primary,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Material 3 Expressive Grouped Cards List
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                children: [
                  // SECTION 1: WORKSPACE
                  _buildSectionHeader(theme, 'Workspace'),
                  const SizedBox(height: 6),
                  _buildSettingsGroup(
                    theme,
                    [
                      _buildM3DrawerTile(
                        theme: theme,
                        icon: Icons.grid_view_rounded,
                        title: 'All Courses',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AllCoursesScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(indent: 58, height: 1),
                      _buildM3DrawerTile(
                        theme: theme,
                        icon: Icons.calendar_month_rounded,
                        title: 'Calendar',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const CalenderScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(indent: 58, height: 1),
                      _buildM3DrawerTile(
                        theme: theme,
                        icon: Icons.checklist_rounded,
                        title: 'To-Do',
                        onTap: () {
                          // Close drawer back to HomeScreen and smoothly expand the To-Do sheet
                          Navigator.of(context).pop();
                          Future.delayed(const Duration(milliseconds: 150), () {
                            DraggableSheet.expand();
                          });
                        },
                      ),
                      const Divider(indent: 58, height: 1),
                      _buildM3DrawerTile(
                        theme: theme,
                        icon: Icons.edit_note_rounded,
                        title: 'Notes',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const NotesScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(indent: 58, height: 1),
                      _buildM3DrawerTile(
                        theme: theme,
                        icon: Icons.auto_awesome_rounded,
                        title: 'AI Chat',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ChatPage(),
                            ),
                          );
                        },
                      ),
                      const Divider(indent: 58, height: 1),
                      _buildM3DrawerTile(
                        theme: theme,
                        icon: Icons.calculate_rounded,
                        title: 'CGPA Calculator',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const CalculateCgpa(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // SECTION 2: FILES & STORAGE
                  _buildSectionHeader(theme, 'Storage & Files'),
                  const SizedBox(height: 6),
                  _buildSettingsGroup(
                    theme,
                    [
                      _buildM3DrawerTile(
                        theme: theme,
                        icon: Icons.folder_copy_rounded,
                        title: 'Course Files',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AllFilesScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(indent: 58, height: 1),
                      _buildM3DrawerTile(
                        theme: theme,
                        icon: Icons.download_done_rounded,
                        title: 'Offline Downloads',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const DownloadsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // SECTION 3: SYSTEM PREFERENCES
                  _buildSectionHeader(theme, 'Preferences'),
                  const SizedBox(height: 6),
                  _buildSettingsGroup(
                    theme,
                    [
                      _buildM3DrawerTile(
                        theme: theme,
                        icon: Icons.settings_rounded,
                        title: 'Settings',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SettingScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),

            // Material 3 Expressive Sign Out Pill
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: GlitterTap(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    await AuthServices().signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const AuthGate(),
                      ),
                      (_) => false,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) =>
      M3SectionHeader(title);

  Widget _buildSettingsGroup(ThemeData theme, List<Widget> children) =>
      M3SettingsGroupCard(borderRadius: 22, children: children);

  Widget _buildIconBadge(ThemeData theme, IconData icon) =>
      M3IconBadge(icon: icon, size: 20, padding: const EdgeInsets.all(7));

  Widget _buildM3DrawerTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: _buildIconBadge(theme, icon),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 19,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
      ),
      onTap: onTap,
    );
  }
}

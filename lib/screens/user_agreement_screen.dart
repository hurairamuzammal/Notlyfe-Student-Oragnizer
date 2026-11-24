import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:notlyfe/services/app_version_service.dart';
import 'package:notlyfe/services/auth_gate.dart';
import 'package:url_launcher/url_launcher.dart';

class UserAgreementScreen extends StatefulWidget {
  final bool isMandatory;

  const UserAgreementScreen({
    super.key,
    this.isMandatory = true,
  });

  @override
  State<UserAgreementScreen> createState() => _UserAgreementScreenState();
}

class _UserAgreementScreenState extends State<UserAgreementScreen> {
  final List<bool> _checked = [false, false, false, false];

  static const List<String> _terms = [
    "I recognize this app is open-source and provided 'as-is' with no warranties, explicit or implied. I fully accept all risks of errors, defects, or failures, using the app solely at my own risk.",
    "I understand there is no warranty for the accuracy, reliability, or completeness of my data. Manual data backup is my responsibility, and I agree to not hold the app liable for any data loss.",
    "I acknowledge that Notlyfe respects my privacy, never aims to steal or monetize user data, and requires my explicit consent and authorization for any cloud sync, Google Drive integration, or external storage.",
    "I hereby release the app developers, contributors, and distributing parties from any liability for claims, damages, legal fees, or losses, including those resulting from device failures, third-party services, or data inaccuracies.",
  ];

  @override
  void initState() {
    super.initState();
    // If opened in review mode, mark all as agreed already
    if (!widget.isMandatory) {
      for (int i = 0; i < _checked.length; i++) {
        _checked[i] = true;
      }
    }
  }

  bool get _allChecked => _checked.every((item) => item);

  void _toggleAll(bool value) {
    setState(() {
      for (int i = 0; i < _checked.length; i++) {
        _checked[i] = value;
      }
    });
  }

  void _toggleItem(int index) {
    setState(() {
      _checked[index] = !_checked[index];
    });
  }

  Future<void> _launchRepo() async {
    final uri = Uri.parse(AppVersionService.repoUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _onContinue() async {
    if (!_allChecked) return;

    try {
      if (Hive.isBoxOpen('testBox')) {
        await Hive.box('testBox').put('userAgreementAccepted', true);
      } else {
        final box = await Hive.openBox('testBox');
        await box.put('userAgreementAccepted', true);
      }
    } catch (e) {
      debugPrint('Error saving agreement: $e');
    }

    if (!mounted) return;

    if (widget.isMandatory) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !widget.isMandatory,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: !widget.isMandatory,
          leading: !widget.isMandatory
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Title
                      Text(
                        'Important User Agreement',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // GitHub / Open Source Pill Badge
                      InkWell(
                        onTap: _launchRepo,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
                                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.code_rounded,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'github.com/hurairamuzammal/Notlyfe-Student-Oragnizer',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.1,
                                    decoration: TextDecoration.underline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Instructions Row with Select All
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Please read and agree to the following terms before using the app:',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _toggleAll(!_allChecked),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _allChecked ? 'Uncheck All' : 'Check All',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Terms Checkbox Items
                      ...List.generate(_terms.length, (index) {
                        final isChecked = _checked[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14.0),
                          child: InkWell(
                            onTap: () => _toggleItem(index),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 2.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Rounded Checkbox
                                  SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: Transform.scale(
                                      scale: 1.15,
                                      child: Checkbox(
                                        value: isChecked,
                                        onChanged: (val) => _toggleItem(index),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        side: BorderSide(
                                          color: isChecked
                                              ? colorScheme.primary
                                              : colorScheme.outline.withValues(alpha: 0.6),
                                          width: 1.8,
                                        ),
                                        activeColor: colorScheme.primary,
                                        checkColor: colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Terms Text
                                  Expanded(
                                    child: Text(
                                      _terms[index],
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontSize: 14,
                                        height: 1.45,
                                        letterSpacing: -0.1,
                                        color: isChecked
                                            ? colorScheme.onSurface
                                            : colorScheme.onSurface.withValues(alpha: 0.8),
                                        fontWeight: isChecked ? FontWeight.w500 : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Bottom Action Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 14.0),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _allChecked ? _onContinue : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      disabledBackgroundColor: colorScheme.primary.withValues(alpha: 0.28),
                      foregroundColor: colorScheme.onPrimary,
                      disabledForegroundColor: colorScheme.onPrimary.withValues(alpha: 0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: _allChecked ? 2 : 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.isMandatory ? 'Agree and Continue' : 'Acknowledge',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                        if (widget.isMandatory) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


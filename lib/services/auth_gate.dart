import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:notlyfe/providers/login_user_provider.dart';
import 'package:notlyfe/providers/note_style_provider.dart';
import 'package:notlyfe/screens/drive_setup_screen.dart';
import 'package:notlyfe/screens/force_update_screen.dart';
import 'package:notlyfe/screens/home_screen.dart';
import 'package:notlyfe/screens/login_signup.dart';
import 'package:notlyfe/screens/reset_password_screen.dart';
import 'package:notlyfe/screens/user_agreement_screen.dart';
import 'package:notlyfe/services/app_version_service.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/services/e2ee_service.dart';
import 'package:notlyfe/services/google_drive_storage_service.dart';
import 'package:notlyfe/widgets/m3_shape_progress_indicator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Root routing gate handling version enforcement, agreement consent,
/// authentication state, E2EE key setup, and one-time Drive setup.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate>
    with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSub;
  Session? _activeSession;
  bool _isPasswordRecovery = false;
  bool _e2eeReady = false;
  bool _needsDriveSetup = false;
  AppVersionPolicy? _blockingUpdate;
  String? _handledUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkVersionGate();

    final auth = Supabase.instance.client.auth;
    _activeSession = auth.currentSession;
    _authSub = auth.onAuthStateChange.listen(_handleAuthEvent);

    if (_activeSession != null) {
      _prepareAuthenticatedUser(_activeSession!.user.id);
    } else if (AuthServices().isLocalGuestMode()) {
      _prepareAuthenticatedUser('local_user');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVersionGate();
    }
  }

  Future<void> _checkVersionGate() async {
    final policy = await AppVersionService.instance.checkForceUpdate();
    if (!mounted) return;
    setState(() => _blockingUpdate = policy);
  }

  void _handleAuthEvent(AuthState authState) {
    if (!mounted) return;
    if (authState.event == AuthChangeEvent.passwordRecovery) {
      setState(() {
        _isPasswordRecovery = true;
        _activeSession = authState.session;
      });
      return;
    }

    final session = authState.session;
    setState(() {
      _isPasswordRecovery = false;
      _activeSession = session;
    });

    if (session != null) {
      _prepareAuthenticatedUser(session.user.id);
    } else if (AuthServices().isLocalGuestMode()) {
      _prepareAuthenticatedUser('local_user');
    } else {
      _handleSignedOut();
    }
  }

  Future<void> _prepareAuthenticatedUser(String userId) async {
    if (_handledUserId == userId && _e2eeReady) return;
    _handledUserId = userId;

    await E2eeService.instance.setUser(userId);
    await GoogleDriveStorageService.instance.ensureInitialized();
    final driveHandled =
        await GoogleDriveStorageService.instance.hasHandledInitialSetup();

    if (!mounted) return;
    setState(() {
      _e2eeReady = true;
      _needsDriveSetup = !driveHandled && userId != 'local_user';
    });

    // Background profile & style sync.
    unawaited(_syncUserMetadata());
  }

  Future<void> _syncUserMetadata() async {
    try {
      await ref.read(noteStyleProvider.notifier).syncFromRemote();
      final cleanName = await AuthServices().ensureUserProfileCreated();
      if (cleanName.isNotEmpty && mounted) {
        ref.read(userNameProvider.notifier).state = cleanName;
      }
    } catch (e) {
      debugPrint('Post-auth metadata sync notice: $e');
    }
  }

  void _handleSignedOut() {
    _handledUserId = null;
    _e2eeReady = false;
    _needsDriveSetup = false;
    E2eeService.instance.clearActiveKey();
  }

  @override
  Widget build(BuildContext context) {
    if (_blockingUpdate != null) {
      return ForceUpdateScreen(
        policy: _blockingUpdate!,
        onRetry: _checkVersionGate,
      );
    }

    final box = Hive.isBoxOpen('testBox') ? Hive.box('testBox') : null;
    final agreementAccepted =
        box?.get('userAgreementAccepted', defaultValue: false) == true;
    if (!agreementAccepted) {
      return const UserAgreementScreen();
    }

    if (_isPasswordRecovery) {
      return const ResetPasswordScreen();
    }

    final isAuthenticated =
        _activeSession != null || AuthServices().isLocalGuestMode();
    if (!isAuthenticated) {
      return const LoginSignupScreen();
    }

    if (!_e2eeReady) {
      return const Scaffold(
        body: Center(
          child: M3ShapeChangingProgressIndicator(size: 40, strokeWidth: 3.5),
        ),
      );
    }

    if (_needsDriveSetup) {
      return DriveSetupScreen(
        onComplete: () {
          if (mounted) setState(() => _needsDriveSetup = false);
        },
      );
    }

    return const HomeScreen();
  }
}

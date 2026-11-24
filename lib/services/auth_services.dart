import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:notlyfe/database/user_profile_database.dart';
import 'package:notlyfe/screens/dragable_sheet.dart';
import 'package:notlyfe/services/e2ee_service.dart';
import 'package:notlyfe/services/google_drive_storage_service.dart';
import 'package:notlyfe/services/password_reset_rate_limiter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles Supabase authentication, Google account linking, and session cleanup.
class AuthServices {
  SupabaseClient get supabaseInstance => Supabase.instance.client;

  static const String _localGuestKey = 'notlyfe_local_guest_mode';

  Future<String> signIn({required LoginData data}) async {
    try {
      await supabaseInstance.auth.signInWithPassword(
        email: data.name,
        password: data.password,
      );
      return '';
    } on AuthRetryableFetchException catch (e) {
      return _friendlyNetworkError(e.message);
    } on AuthException catch (e) {
      return getAuthErrorMessage(e);
    } on SocketException {
      return _friendlyNetworkError('SocketException');
    } catch (e) {
      return _friendlyNetworkError(e.toString());
    }
  }

  String _friendlyNetworkError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception')) {
      return 'Cannot reach cloud server. Check your internet connection and try again.';
    }
    return 'Unable to sign in right now. Please try again.';
  }

  Future<String> signUp({required SignupData data}) async {
    try {
      final response = await supabaseInstance.auth.signUp(
        email: data.name!,
        password: data.password!,
      );
      if (response.user != null) {
        return response.user!.id;
      }
      return 'Sign-up failed. Please try again.';
    } on AuthRetryableFetchException catch (e) {
      return _friendlyNetworkError(e.message);
    } on AuthException catch (e) {
      return getAuthErrorMessage(e);
    } on SocketException {
      return _friendlyNetworkError('SocketException');
    } catch (e) {
      return _friendlyNetworkError(e.toString());
    }
  }

  /// Signs in with Google. On Android/iOS this uses the native account sheet
  /// and persists Google Drive access in the same step so setup happens once.
  Future<String> signInWithGoogle() async {
    try {
      String? extractedCleanName;
      String? extractedEmail;
      final driveService = GoogleDriveStorageService.instance;

      if (driveService.isNativeSignInSupported) {
        try {
          await driveService.ensureInitialized();
          final account = await GoogleSignIn.instance.authenticate(
            scopeHint: GoogleDriveStorageService.strictDriveScopes,
          );

          extractedEmail = account.email;
          extractedCleanName = UserProfileDatabase.sanitizeDisplayName(
            account.displayName,
            fallbackEmail: account.email,
          );

          final idToken = account.authentication.idToken;
          if (idToken != null && idToken.isNotEmpty) {
            String? accessToken;
            try {
              final authz = await account.authorizationClient
                  .authorizationForScopes(
                GoogleDriveStorageService.strictDriveScopes,
              );
              accessToken = authz?.accessToken;
            } catch (_) {}

            final authResponse = await supabaseInstance.auth.signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: idToken,
              accessToken: accessToken,
            );
            if (authResponse.session != null) {
              if (accessToken != null && accessToken.isNotEmpty) {
                await driveService.saveConnectedSession(
                  email: extractedEmail,
                  accessToken: accessToken,
                  displayName: extractedCleanName,
                  ownerUserId: authResponse.user?.id,
                  account: account,
                );
              }
              if (authResponse.user != null &&
                  extractedCleanName.isNotEmpty) {
                await UserProfileDatabase().updateUserName(
                  authResponse.user!.id,
                  extractedCleanName,
                );
              }
              recordGoogleLinkedEmail(extractedEmail);
              return '';
            }
          }
        } on GoogleSignInException catch (e) {
          if (e.code == GoogleSignInExceptionCode.canceled) {
            return 'Google sign-in was cancelled.';
          }
          debugPrint('Native GoogleSignIn fallback to OAuth: $e');
        } catch (nativeErr) {
          debugPrint('Native GoogleSignIn fallback to OAuth: $nativeErr');
        }
      }

      final launched = await supabaseInstance.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'notlyfe://login-callback',
        scopes: 'https://www.googleapis.com/auth/drive.file',
        authScreenLaunchMode: driveService.isNativeSignInSupported
            ? LaunchMode.inAppBrowserView
            : LaunchMode.externalApplication,
        queryParams: {
          'access_type': 'offline',
          if (extractedEmail != null && extractedEmail.isNotEmpty)
            'login_hint': extractedEmail
          else
            'prompt': 'select_account',
        },
      );

      if (!launched) {
        return 'Could not launch Google authentication window.';
      }
      return '';
    } on AuthException catch (e) {
      return getAuthErrorMessage(e);
    } on SocketException {
      return 'Network error: Please check your internet connection.';
    } catch (_) {
      return 'Google sign-in failed. Please try again.';
    }
  }

  Future<String> linkGoogleAccount() async {
    try {
      final user = supabaseInstance.auth.currentUser;
      if (user == null) {
        return 'You must be signed in to link your Google account.';
      }
      if (await isGoogleLinked()) {
        return 'This account is already linked with Google.';
      }

      final launched = await supabaseInstance.auth.linkIdentity(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'notlyfe://login-callback',
      );
      return launched ? '' : 'Could not launch Google linking window.';
    } on AuthException catch (e) {
      return getAuthErrorMessage(e);
    } on SocketException {
      return 'Network error: Please check your internet connection.';
    } catch (_) {
      return 'Failed to link Google account. Please try again.';
    }
  }

  Future<String> unlinkGoogleAccount() async {
    try {
      final user = supabaseInstance.auth.currentUser;
      if (user == null) return 'No user is currently signed in.';

      final identities = await supabaseInstance.auth.getUserIdentities();
      if (identities.length <= 1) {
        return 'Cannot unlink Google: it is your only sign-in method.';
      }

      final googleIdentity = identities.firstWhere(
        (id) => id.provider.toLowerCase() == 'google',
        orElse: () => throw Exception('Google account is not linked.'),
      );
      await supabaseInstance.auth.unlinkIdentity(googleIdentity);
      return '';
    } on AuthException catch (e) {
      return getAuthErrorMessage(e);
    } on SocketException {
      return 'Network error: Please check your internet connection.';
    } catch (_) {
      return 'Failed to unlink Google account. Please try again.';
    }
  }

  Future<bool> isGoogleLinked() async {
    final user = supabaseInstance.auth.currentUser;
    if (user == null) return false;

    if (user.identities != null &&
        user.identities!.any((id) => id.provider.toLowerCase() == 'google')) {
      recordGoogleLinkedEmail(user.email);
      return true;
    }

    final providers = user.appMetadata['providers'];
    if (providers is List &&
        providers.any((p) => p.toString().toLowerCase() == 'google')) {
      recordGoogleLinkedEmail(user.email);
      return true;
    }
    if (user.appMetadata['provider']?.toString().toLowerCase() == 'google') {
      recordGoogleLinkedEmail(user.email);
      return true;
    }

    try {
      final identities = await supabaseInstance.auth.getUserIdentities();
      final hasGoogle =
          identities.any((id) => id.provider.toLowerCase() == 'google');
      if (hasGoogle) recordGoogleLinkedEmail(user.email);
      return hasGoogle;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getGoogleLinkedEmail() async {
    final user = supabaseInstance.auth.currentUser;
    if (user == null) return null;

    try {
      final identities =
          user.identities ?? await supabaseInstance.auth.getUserIdentities();
      for (final id in identities) {
        if (id.provider.toLowerCase() == 'google') {
          final email = id.identityData?['email'];
          if (email != null && email.toString().isNotEmpty) {
            return email.toString();
          }
        }
      }
    } catch (_) {}

    return user.email;
  }

  void recordGoogleLinkedEmail(String? email) {
    if (email == null || email.trim().isEmpty) return;
    try {
      if (!Hive.isBoxOpen('testBox')) return;
      final box = Hive.box('testBox');
      final list =
          (box.get('google_linked_emails', defaultValue: <dynamic>[]) as List)
              .map((e) => e.toString().toLowerCase())
              .toSet();
      list.add(email.trim().toLowerCase());
      box.put('google_linked_emails', list.toList());
    } catch (_) {}
  }

  bool isEmailGoogleLinked(String email) {
    try {
      if (!Hive.isBoxOpen('testBox')) return false;
      final list = (Hive.box('testBox')
              .get('google_linked_emails', defaultValue: <dynamic>[]) as List)
          .map((e) => e.toString().toLowerCase())
          .toList();
      return list.contains(email.trim().toLowerCase());
    } catch (_) {
      return false;
    }
  }

  Future<String> ensureUserProfileCreated() async {
    final user = supabaseInstance.auth.currentUser;
    if (user == null) return '';

    try {
      var existingName = await UserProfileDatabase().getUserName(user.id);
      var rawMetaName = user.userMetadata?['full_name']?.toString() ??
          user.userMetadata?['name']?.toString();

      if ((rawMetaName == null || rawMetaName.trim().isEmpty) &&
          user.identities != null) {
        for (final id in user.identities!) {
          final idName = id.identityData?['full_name']?.toString() ??
              id.identityData?['name']?.toString();
          if (idName != null && idName.trim().isNotEmpty) {
            rawMetaName = idName;
            break;
          }
        }
      }

      if (rawMetaName == null || rawMetaName.trim().isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        rawMetaName = prefs.getString('gdrive_display_name');
      }

      final cleanName = UserProfileDatabase.sanitizeDisplayName(
        existingName.isNotEmpty && existingName != 'Notlyfe User'
            ? existingName
            : rawMetaName,
        fallbackEmail: user.email,
      );

      if (existingName.isEmpty ||
          existingName == 'Anonymous' ||
          existingName == 'Notlyfe User' ||
          existingName != cleanName) {
        if (cleanName.isNotEmpty) {
          await UserProfileDatabase().updateUserName(user.id, cleanName);
          existingName = cleanName;
        }
      }

      if (await isGoogleLinked()) {
        recordGoogleLinkedEmail(user.email);
      }
      return existingName;
    } catch (e) {
      debugPrint('Profile sync error: $e');
      return '';
    }
  }

  /// Sends a password reset link, enforcing a local 3-requests/24h cap.
  Future<String> resetPassword(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      return 'Please enter a valid email address.';
    }

    if (isEmailGoogleLinked(cleanEmail)) {
      return 'This account uses Google Sign-In. Please sign in directly with Google.';
    }

    final rateLimitError =
        await PasswordResetRateLimiter.checkRateLimit(cleanEmail);
    if (rateLimitError != null) return rateLimitError;

    try {
      await supabaseInstance.auth.resetPasswordForEmail(
        cleanEmail,
        redirectTo: 'https://hurairamuzammal.github.io/notlyfe-reset/',
      );
      await PasswordResetRateLimiter.recordResetAttempt(cleanEmail);
      return '';
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('google') ||
          msg.contains('oauth') ||
          msg.contains('provider') ||
          msg.contains('no password')) {
        recordGoogleLinkedEmail(cleanEmail);
        return 'This account uses Google Sign-In. Please sign in directly with Google.';
      }
      return getAuthErrorMessage(e);
    } on SocketException {
      return 'Network error: Please check your internet connection.';
    } catch (_) {
      return 'Could not send reset email. Please try again.';
    }
  }

  /// Signs out and scrubs in-memory user data, E2EE keys, and legacy session caches.
  Future<void> signOut() async {
    await setLocalGuestMode(false);
    E2eeService.instance.clearActiveKey();
    DraggableSheet.clearTodos();

    try {
      if (Hive.isBoxOpen('testBox')) {
        final box = Hive.box('testBox');
        await box.delete('cached_user_name');
        await box.delete('google_provider_token');
      }
      if (Hive.isBoxOpen('test_box')) {
        await Hive.box('test_box').delete('supabase_session');
      }
    } catch (_) {}

    try {
      await supabaseInstance.auth.signOut();
    } catch (_) {}
  }

  bool isLocalGuestMode() {
    try {
      if (Hive.isBoxOpen('testBox')) {
        return Hive.box('testBox').get(_localGuestKey, defaultValue: false) ==
            true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> setLocalGuestMode(bool enabled) async {
    try {
      if (Hive.isBoxOpen('testBox')) {
        await Hive.box('testBox').put(_localGuestKey, enabled);
      }
    } catch (_) {}
  }

  String getCurrentUserId() {
    try {
      final user = supabaseInstance.auth.currentUser;
      if (user != null) return user.id;
    } catch (_) {}
    if (isLocalGuestMode()) return 'local_user';
    throw StateError('No user is currently signed in.');
  }

  String getAuthErrorMessage(AuthException exception) {
    switch (exception.code) {
      case 'email_not_confirmed':
        return 'Please confirm your email address to proceed.';
      case 'invalid_credentials':
        return 'Invalid email or password. Please try again.';
      case 'email_exists':
        return 'This email is already registered. Try logging in instead.';
      case 'weak_password':
        return 'Password is too weak. Please use a stronger password.';
      case 'session_expired':
        return 'Your session has expired. Please log in again.';
      case 'otp_expired':
        return 'The verification code has expired. Please request a new one.';
      default:
        return exception.message;
    }
  }
}

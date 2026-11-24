import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notlyfe/database/user_profile_database.dart';
import 'package:notlyfe/services/auth_services.dart';
import 'package:notlyfe/services/password_reset_rate_limiter.dart';

class LoginSignupScreen extends StatefulWidget {
  const LoginSignupScreen({super.key});

  @override
  State<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen> {
  final authInstance = AuthServices();
  final userProfileDBInstance = UserProfileDatabase();

  double _scrollOffset = 0.0;
  // Distance in pixels over which the logo flies next to the text
  static const double _flightTriggerDistance = 100.0;

  Future<String> login(LoginData data) async {
    try {
      final result = await authInstance.signIn(data: data);
      return result.isEmpty ? '' : result;
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<String> signUp(SignupData data) async {
    try {
      final rawFullName = data.additionalSignupData?['Full name']?.toString();
      final fullName = UserProfileDatabase.sanitizeDisplayName(
        rawFullName,
        fallbackEmail: data.name,
      );

      final userId = await authInstance.signUp(data: data);
      if (userId.isEmpty) {
        return 'Sign-up failed. Unable to retrieve user information.';
      }

      await userProfileDBInstance.addUserProfile(userId, fullName);
      return '';
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<String?> recoverPassword(String email) async {
    try {
      final clean = email.trim();
      if (clean.isEmpty) {
        return 'Please enter a valid email address.';
      }

      if (authInstance.isEmailGoogleLinked(clean)) {
        return 'This account is linked with Google. Google-linked accounts cannot reset passwords. Please sign in using Google.';
      }

      // Enforce 3 requests per 24 hours rate limit
      final rateLimitMsg = await PasswordResetRateLimiter.checkRateLimit(clean);
      if (rateLimitMsg != null) {
        return rateLimitMsg;
      }

      final res = await authInstance.resetPassword(clean);
      return res.isEmpty ? null : res;
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceHeight = MediaQuery.of(context).size.height;
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final theme = Theme.of(context);

    // 0.0 = resting state (logo on top, title below)
    // 1.0 = flight complete (logo has moved directly next to the title in a single horizontal row)
    final progress = (_scrollOffset / _flightTriggerDistance).clamp(0.0, 1.0);

    // Dynamic measurements
    final logoSize = 75.0 - (27.0 * progress); // 75 down to 48
    final headerTopOffset = max(8.0, 32.0 - (24.0 * progress));

    return Scaffold(
      body: Stack(
        children: [
          // FlutterLogin card and form fields
          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.axis == Axis.vertical) {
                setState(() {
                  _scrollOffset = scrollInfo.metrics.pixels;
                });
              }
              return false;
            },
            child: FlutterLogin(
              logo: null,
              title: null,
              theme: LoginTheme(
                cardTopPosition: min(deviceHeight * 0.36, 280.0),
                headerMargin: 10,
                buttonTheme: LoginButtonTheme(
                  backgroundColor: theme.colorScheme.primary,
                  highlightColor: theme.colorScheme.secondary,
                  splashColor: theme.colorScheme.secondary,
                  elevation: 4,
                  highlightElevation: 10,
                ),
                cardTheme: CardTheme(
                  elevation: 16,
                  shadowColor: theme.colorScheme.secondary.withValues(alpha: 0.3),
                  color: isDarkMode
                      ? theme.colorScheme.surface
                      : theme.colorScheme.onPrimary,
                ),
                accentColor: theme.colorScheme.primaryFixedDim,
              ),
              scrollable: true,
              onLogin: (data) async => login(data),
              additionalSignupFields: const [
                UserFormField(
                  keyName: 'Full name',
                  displayName: 'Full Name',
                  icon: Icon(Icons.person),
                ),
              ],
              loginAfterSignUp: false,
              onSignup: (data) async => signUp(data),
              onRecoverPassword: (email) async => recoverPassword(email),
              messages: LoginMessages(
                providersTitleFirst: 'or sign up / login with',
                recoverPasswordIntro: 'Password Recovery',
                recoverPasswordDescription:
                    'We will send a reset link to your email (max 3 per 24 hours). Note: Google-linked accounts cannot reset passwords.',
              ),
              loginProviders: <LoginProvider>[
                LoginProvider(
                  icon: Icons.g_mobiledata,
                  label: 'Google',
                  callback: () async {
                    try {
                      final error = await authInstance.signInWithGoogle();
                      if (error.isNotEmpty) {
                        return error;
                      }
                      return null;
                    } catch (e) {
                      return 'Failed to sign in with Google: ${e.toString()}';
                    }
                  },
                ),
              ],
              onSubmitAnimationCompleted: () {},
            ),
          ),

          // Animated Flight Header (Logo & App Name)
          // Starts stacked (Logo above text), and on scroll smoothly flies to side-by-side in one row
          Positioned(
            top: headerTopOffset,
            left: 0,
            right: 0,
            child: SafeArea(
              child: IgnorePointer(
                child: SizedBox(
                  height: 140,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // The Logo Icon: Flies from centered top (y: -36, x: 0) to next-to-text (y: 0, x: -75)
                        Transform.translate(
                          offset: Offset(
                            -72.0 * progress,
                            -36.0 * (1.0 - progress),
                          ),
                          child: Image.asset(
                            'assets/icon/monochrome_3.png',
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.contain,
                            color: isDarkMode
                                ? theme.colorScheme.primary
                                : (progress > 0.4
                                    ? theme.colorScheme.primary
                                    : Colors.white),
                          ),
                        ),

                        // The App Name "Notlyfe": Shifts slightly down-right to lock alongside the logo
                        Transform.translate(
                          offset: Offset(
                            22.0 * progress,
                            22.0 * (1.0 - progress),
                          ),
                          child: Text(
                            'Notlyfe',
                            style: GoogleFonts.caveat(
                              fontSize: 46 - (6.0 * progress),
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? theme.colorScheme.primary
                                  : (progress > 0.4
                                      ? theme.colorScheme.primary
                                      : Colors.white),
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 1.5),
                                  blurRadius: 4,
                                  color: Colors.black.withValues(alpha: 0.35),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

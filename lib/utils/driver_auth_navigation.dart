import 'package:flutter/material.dart';

import '../features/auth/verification/verification_args.dart';
import '../features/auth/widgets/auth_top_toast.dart';
import '../features/profile/manage_vehicle_view.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/driver_status_service.dart';
import '../features/splash/splash_video_model.dart';
import 'driver_navigation_target.dart';

class DriverAuthNavigation {
  DriverAuthNavigation._();

  static bool isSessionExpiredMessage(String? message) {
    if (message == null || message.isEmpty) return false;
    return AuthService.isAuthErrorMessage(message);
  }

  /// Clears invalid tokens and sends the user to login (full stack reset).
  /// Only navigates away when there is no persisted session to restore.
  static Future<void> redirectToLogin(BuildContext context) async {
    await AuthService.maintainSession();
    if (!context.mounted) return;
    if (AuthService.hasValidSession) {
      return;
    }
    await Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  }

  /// Restores session when possible; only redirects to login without stored credentials.
  static Future<bool> ensureSessionOrRedirectToLogin(BuildContext context) async {
    final restored = await AuthService.maintainSession();
    if (restored || !context.mounted) return restored;
    if (AuthService.hasValidSession) return true;
    await Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
    return false;
  }

  static String routeForAccess(DriverAccessRoute route) {
    switch (route) {
      case DriverAccessRoute.login:
        return AppRoutes.login;
      case DriverAccessRoute.phoneVerification:
        return AppRoutes.verification;
      case DriverAccessRoute.dashboard:
        return AppRoutes.home;
      case DriverAccessRoute.documentUpload:
        return AppRoutes.documentUpload;
      case DriverAccessRoute.manageVehicle:
        return AppRoutes.manageVehicle;
      case DriverAccessRoute.pendingApproval:
        return AppRoutes.documentSubmissionSuccess;
    }
  }

  static Future<String> resolveRouteAfterAuth({
    Map<String, dynamic>? loginResponse,
  }) async {
    final target = await resolveNavigationTarget(loginResponse: loginResponse);
    return target.route;
  }

  static Future<DriverNavigationTarget> resolveNavigationTarget({
    Map<String, dynamic>? loginResponse,
  }) async {
    final accessRoute = await resolveAccessRouteAfterAuth(
      loginResponse: loginResponse,
    );
    return targetForAccessRoute(accessRoute);
  }

  static Future<DriverNavigationTarget> targetForAccessRoute(
    DriverAccessRoute accessRoute,
  ) async {
    if (accessRoute == DriverAccessRoute.documentUpload ||
        accessRoute == DriverAccessRoute.manageVehicle) {
      await AuthService.ensureAuthenticatedSession();
    }

    if (accessRoute == DriverAccessRoute.phoneVerification) {
      if (AuthService.isLoggedIn) {
        final backendRoute = await AuthService.resolveSignupRouteFromBackend();
        if (backendRoute != null &&
            backendRoute != DriverAccessRoute.phoneVerification) {
          return targetForAccessRoute(backendRoute);
        }
      }

      final route = routeForAccess(accessRoute);
      final args = await resolveVerificationArgs();
      if (args != null && args.hasValidPhone) {
        return DriverNavigationTarget(route: route, arguments: args);
      }
      return DriverNavigationTarget(route: AuthService.unauthenticatedEntryRoute);
    }

    if (accessRoute == DriverAccessRoute.manageVehicle) {
      return DriverNavigationTarget(
        route: AppRoutes.manageVehicle,
        arguments: const ManageVehicleArgs(fromOnboarding: true),
      );
    }

    return DriverNavigationTarget(route: routeForAccess(accessRoute));
  }

  /// Fast splash path for returning users — uses stored session and onboarding
  /// progress from disk instead of waiting on backend round-trips.
  static Future<DriverNavigationTarget?> resolveFastReturningSplashTarget() async {
    if (!AuthService.hasValidSession) return null;

    final storedRoute = await DriverStatusService.resolveStoredAccessRoute();
    if (storedRoute == null || storedRoute == DriverAccessRoute.dashboard) {
      return const DriverNavigationTarget(route: AppRoutes.home);
    }

    if (storedRoute == DriverAccessRoute.login ||
        storedRoute == DriverAccessRoute.phoneVerification) {
      return null;
    }

    return targetForAccessRoute(storedRoute);
  }

  /// Splash: restore session, ask backend onboarding status, resume correct screen.
  static Future<DriverNavigationTarget> resolveSplashTarget() async {
    await AuthService.loadStoredSessionFromDisk();
    await AuthService.maintainSession();

    if (AuthService.hasValidSession) {
      await AuthService.clearPendingPhoneContext();
    }

    final phoneVerifiedResume =
        await AuthService.hasCompletedPhoneVerificationResume();
    if (phoneVerifiedResume) {
      if (!AuthService.hasValidSession) {
        await AuthService.maintainSession();
      }
      if (AuthService.hasValidSession) {
        final backendTarget = await _targetFromBackendRoute();
        if (backendTarget != null) {
          return backendTarget;
        }
        return DriverNavigationTarget(route: AppRoutes.home);
      }
      return DriverNavigationTarget(route: AppRoutes.login);
    }

    if (!AuthService.hasValidSession) {
      await AuthService.maintainSession();
    }

    final backendTarget = await _targetFromBackendRoute();
    if (backendTarget != null) {
      return backendTarget;
    }

    if (!AuthService.hasValidSession &&
        await AuthService.hasPendingSignupCredentials()) {
      await AuthService.maintainSession();
      final retryTarget = await _targetFromBackendRoute();
      if (retryTarget != null) {
        return retryTarget;
      }
    }

    if (!AuthService.hasValidSession) {
      final pending = await AuthService.loadPendingVerificationContext();
      if (pending != null && pending.hasValidPhone) {
        return DriverNavigationTarget(
          route: AppRoutes.verification,
          arguments: pending,
        );
      }
    }

    final storedRoute = await DriverStatusService.resolveStoredAccessRoute();
    if (storedRoute != null &&
        storedRoute != DriverAccessRoute.login &&
        storedRoute != DriverAccessRoute.phoneVerification) {
      if (!AuthService.hasValidSession) {
        await AuthService.bootstrapPendingSignupSession();
      }
      if (AuthService.hasValidSession ||
          await AuthService.bootstrapPendingSignupSession()) {
        return targetForAccessRoute(storedRoute);
      }
    }

    final hasResumeData = phoneVerifiedResume ||
        storedRoute != null ||
        await AuthService.hasPendingSignupCredentials();
    if (!AuthService.hasValidSession && !hasResumeData) {
      await AuthService.clearStaleDriverProgress();
    }

    if (AuthService.hasValidSession) {
      final storedRoute = await DriverStatusService.resolveStoredAccessRoute();
      if (storedRoute != null &&
          storedRoute != DriverAccessRoute.login &&
          storedRoute != DriverAccessRoute.phoneVerification) {
        return targetForAccessRoute(storedRoute);
      }
      return DriverNavigationTarget(route: AppRoutes.home);
    }

    return DriverNavigationTarget(route: AuthService.unauthenticatedEntryRoute);
  }

  static Future<DriverNavigationTarget?> _targetFromBackendRoute() async {
    final route = await AuthService.resolveSignupRouteFromBackend();
    if (route == null || route == DriverAccessRoute.login) {
      return null;
    }

    return targetForAccessRoute(route);
  }

  static Future<VerificationArgs?> resolveVerificationArgs() async {
    if (!AuthService.isLoggedIn) {
      final pending = await AuthService.loadPendingVerificationContext();
      if (pending != null && pending.hasValidPhone) return pending;
      return null;
    }

    final profile = await AuthService.getUserProfile();
    if (profile['success'] != true) return null;

    final data = profile['data'];
    if (data is! Map) return null;
    final payload = data['data'] is Map ? data['data'] as Map : data;

    final phone = AuthService.extractProfilePhone(
      Map<String, dynamic>.from(payload),
    );
    if (phone == null || phone.trim().isEmpty) return null;

    final email = AuthService.extractProfileEmail(
      Map<String, dynamic>.from(payload),
    );

    final args = VerificationArgs.fromPhone(
      phone: phone,
      email: email,
    );
    return args.hasValidPhone ? args : null;
  }

  static Future<DriverAccessRoute> resolveAccessRouteAfterAuth({
    Map<String, dynamic>? loginResponse,
  }) async {
    if (loginResponse != null) {
      await AuthService.persistReferralFromAuthResponse(loginResponse);
      await DriverStatusService.clearStored();

      final warning = DriverStatusService.extractWarningFromLogin(loginResponse);
      final loginStatus = DriverStatusService.extractFromLogin(loginResponse);
      if (loginStatus != null) {
        await DriverStatusService.persist(
          loginStatus,
          warningMessage: warning,
          statusResponse: loginResponse,
        );
        final route = DriverStatusService.resolveRoute(status: loginStatus);
        if (route == DriverAccessRoute.dashboard) {
          await DriverStatusService.clearStored();
          await AuthService.clearCompletedSignupLocalState();
        }
        return route;
      }
    }

    if (loginResponse == null && AuthService.isLoggedIn) {
      final route = await AuthService.resolveSignupRouteFromBackend();
      if (route != null) {
        if (route == DriverAccessRoute.dashboard) {
          await DriverStatusService.clearStored();
          await AuthService.clearCompletedSignupLocalState();
        }
        return route;
      }
    }

    final warning = DriverStatusService.extractWarningFromLogin(loginResponse);
    final loginStatus = DriverStatusService.extractFromLogin(loginResponse);

    Map<String, dynamic>? onboardingResponse;
    if (AuthService.isLoggedIn &&
        (loginResponse == null || loginStatus == null)) {
      onboardingResponse = await AuthService.getDriverOnboardingStatus();
      if (AuthService.isUserDeletedResponse(onboardingResponse)) {
        await AuthService.signOut();
        return DriverAccessRoute.login;
      }
      if (AuthService.isUnauthorizedResponse(onboardingResponse)) {
        await AuthService.recoverStoredSession();
      }
    }

    Map<String, dynamic>? profile;
    if (AuthService.isLoggedIn || AuthService.hasStoredSession) {
      profile = await AuthService.getUserProfile();
      if (AuthService.isUserDeletedResponse(profile)) {
        await AuthService.signOut();
        return DriverAccessRoute.login;
      }
      if (AuthService.isUnauthorizedResponse(profile)) {
        await AuthService.recoverStoredSession();
      }
    }

    var status = DriverStatusService.merge(
      loginStatus,
      DriverStatusService.extractFromOnboarding(onboardingResponse),
    );
    status = DriverStatusService.merge(
      status,
      DriverStatusService.extractFromProfile(profile),
    );

    if (AuthService.isLoggedIn) {
      final stored = await DriverStatusService.loadStored();
      if (stored != null && status?.isFullyApproved != true) {
        status = DriverStatusService.merge(status, stored);
      }
    }

    if (status != null) {
      await DriverStatusService.persist(
        status,
        warningMessage: warning,
        statusResponse: onboardingResponse ?? profile ?? loginResponse,
      );
    }

    final route = DriverStatusService.resolveRoute(status: status);
    if (route == DriverAccessRoute.dashboard) {
      await DriverStatusService.clearStored();
      await AuthService.clearCompletedSignupLocalState();
    }
    return route;
  }

  static Future<void> navigateAfterAuth(
    BuildContext context, {
    Map<String, dynamic>? loginResponse,
    bool replace = true,
  }) async {
    await SplashVideoModel.suppressIntro();
    try {
      final target = await resolveNavigationTarget(loginResponse: loginResponse);
      if (!context.mounted) return;

      if (loginResponse != null &&
          loginResponse['success'] == true &&
          target.route == AppRoutes.login) {
        AuthTopToast.showError(
          context,
          'Session could not be restored. Please try signing in again.',
        );
        return;
      }

      if (replace) {
        if (target.route == AppRoutes.home) {
          AuthService.shouldRefreshHomeWallet = true;
        }
        await Navigator.of(context).pushReplacementNamed(
          target.route,
          arguments: target.arguments,
        );
      } else {
        if (target.route == AppRoutes.home) {
          AuthService.shouldRefreshHomeWallet = true;
        }
        await Navigator.of(context).pushNamed(
          target.route,
          arguments: target.arguments,
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      AuthTopToast.showError(
        context,
        'Could not continue after sign in. Please try again.',
      );
    }
  }
}

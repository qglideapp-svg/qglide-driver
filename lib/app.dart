import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_navigator_key.dart';
import 'config/app_constants.dart';
import 'config/app_strings.dart';
import 'config/app_theme.dart';
import 'core/providers/app_providers.dart';
import 'routes/app_routes.dart';
import 'services/ad_placement_service.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'services/ride_request_sound_service.dart';
import 'shared/widgets/app_strings_scope.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdPlacementCache.instance.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        AdPlacementCache.instance.start();
        unawaited(RideRequestSoundService.stop());
        unawaited(AuthService.maintainSession());
        unawaited(PushNotificationService.registerTokenIfLoggedIn());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        AdPlacementCache.instance.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(localeProvider, (previous, next) {
      if (previous != next) {
        AdPlacementCache.instance.refreshForLocaleChange();
      }
    });

    final isArabic = ref.watch(localeProvider);
    final strings = AppStrings(isArabic: isArabic);
    final locale = isArabic ? const Locale('ar') : const Locale('en');

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: AppConstants.appTitle,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return AppStringsScope(
          strings: strings,
          child: Directionality(
            textDirection: strings.textDirection,
            child: MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: mediaQuery.textScaler.clamp(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.2,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}

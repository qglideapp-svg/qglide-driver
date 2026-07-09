import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'app.dart';
import 'features/splash/splash_video_model.dart';
import 'services/app_locale_service.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final imagePicker = ImagePickerPlatform.instance;
    if (imagePicker is ImagePickerAndroid) {
      imagePicker.useAndroidPhotoPicker = true;
    }
  }
  await AppLocaleService.instance.load();
  await AuthService.loadStoredSession();

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      await PushNotificationService.initialize();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Firebase/FCM init failed: $e');
        debugPrint('$stackTrace');
      }
    }
  }

  SplashVideoModel.preload();
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

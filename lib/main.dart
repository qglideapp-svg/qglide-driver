import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'app_bootstrap.dart';
import 'services/app_locale_service.dart';
import 'services/app_tutorial_service.dart';
import 'services/auth_service.dart';
import 'services/splash_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Required for foreground-task ↔ UI communication.
  FlutterForegroundTask.initCommunicationPort();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final imagePicker = ImagePickerPlatform.instance;
    if (imagePicker is ImagePickerAndroid) {
      imagePicker.useAndroidPhotoPicker = true;
    }
  }

  await AppLocaleService.instance.load();
  await AuthService.loadStoredSessionFromDisk();
  await AuthService.maintainSession();
  await AppTutorialService.loadFromDisk();
  await SplashService.loadFromDisk();

  runApp(
    const ProviderScope(
      child: AppBootstrap(),
    ),
  );
}

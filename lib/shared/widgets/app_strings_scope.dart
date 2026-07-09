import 'package:flutter/material.dart';

import '../../config/app_strings.dart';

/// Provides localized strings to the widget tree below [MaterialApp].
class AppStringsScope extends InheritedWidget {
  const AppStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  static AppStrings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStringsScope>();
    assert(scope != null, 'AppStringsScope not found in widget tree');
    return scope!.strings;
  }

  static AppStrings? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppStringsScope>()
        ?.strings;
  }

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) {
    return oldWidget.strings.isArabic != strings.isArabic;
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes the user's language preference app-wide.
class AppLocaleService {
  AppLocaleService._();

  static const _localeKey = 'app_locale';
  static final AppLocaleService instance = AppLocaleService._();

  bool _isArabic = false;
  var _loaded = false;

  bool get isLoaded => _loaded;
  bool get isArabic => _isArabic;
  bool get isEnglish => !_isArabic;
  String get languageCode => _isArabic ? 'ar' : 'en';
  Locale get locale => Locale(languageCode);
  TextDirection get textDirection =>
      _isArabic ? TextDirection.rtl : TextDirection.ltr;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isArabic = prefs.getString(_localeKey) == 'ar';
    } catch (_) {
      _isArabic = false;
    }
    _loaded = true;
  }

  Future<void> setArabic(bool value) async {
    _isArabic = value;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, value ? 'ar' : 'en');
    } catch (_) {
      // Keep in-memory value even if persistence fails.
    }
  }

  Future<void> setEnglish() => setArabic(false);

  Future<void> toggle() => setArabic(!_isArabic);
}

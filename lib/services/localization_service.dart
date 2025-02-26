import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static const String LANG_KEY = 'selected_language';
  static const String DEFAULT_LANG = 'en';

  late Map<String, dynamic> _localizedStrings;
  String _currentLanguage = DEFAULT_LANG;

  String get currentLanguage => _currentLanguage;

  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(LANG_KEY) ?? DEFAULT_LANG;
    await loadLanguage(_currentLanguage);
  }

  Future<void> setLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LANG_KEY, langCode);
    _currentLanguage = langCode;
    await loadLanguage(langCode);
    notifyListeners();
  }

  Future<void> loadLanguage(String langCode) async {
    String jsonString = await rootBundle.loadString('assets/lang/$langCode.json');
    _localizedStrings = json.decode(jsonString);
  }

  String translate(String key, [Map<String, dynamic>? args]) {
    List<String> keys = key.split('.');
    dynamic value = _localizedStrings;
    
    for (String k in keys) {
      if (value is! Map) return key;
      value = value[k];
      if (value == null) return key;
    }
    
    String result = value.toString();
    
    if (args != null) {
      args.forEach((key, value) {
        result = result.replaceAll('{$key}', value.toString());
      });
    }
    
    return result;
  }

  static List<Map<String, String>> get supportedLanguages => [
    {'code': 'en', 'name': 'English'},
    {'code': 'ru', 'name': 'Русский'},
    {'code': 'de', 'name': 'Deutsch'},
    {'code': 'es', 'name': 'Español'},
    {'code': 'fr', 'name': 'Français'},
    {'code': 'it', 'name': 'Italiano'},
    {'code': 'ja', 'name': '日本語'},
    {'code': 'ko', 'name': '한국어'},
    {'code': 'pl', 'name': 'Polski'},
    {'code': 'pt', 'name': 'Português'},
    {'code': 'tr', 'name': 'Türkçe'},
    {'code': 'zh', 'name': '中文'},
    {'code': 'el', 'name': 'Elvish/Эльфийский'}
  ];
} 
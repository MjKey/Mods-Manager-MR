import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _gamePathCacheKey = 'game_path_cache';
  static const Duration _cacheValidityDuration = Duration(days: 7);
  
  static SharedPreferences? _prefs;

  static Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> cacheGamePath(String? path) async {
    await _initPrefs();
    final cache = {
      'path': path,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _prefs!.setString(_gamePathCacheKey, jsonEncode(cache));
  }

  static Future<String?> getCachedGamePath() async {
    await _initPrefs();
    final cacheJson = _prefs!.getString(_gamePathCacheKey);
    if (cacheJson == null) return null;

    try {
      final cache = jsonDecode(cacheJson) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cache['timestamp'] as String);
      final path = cache['path'] as String?;

      // Проверяем валидность кэша
      if (path != null && 
          DateTime.now().difference(timestamp) < _cacheValidityDuration) {
        return path;
      }
    } catch (e) {
      print('Ошибка при чтении кэша: $e');
    }
    
    return null;
  }

  static Future<void> clearCache() async {
    await _initPrefs();
    await _prefs!.remove(_gamePathCacheKey);
  }
} 
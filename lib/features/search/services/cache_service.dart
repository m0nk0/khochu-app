import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class CacheService {
  static const String _cacheKey = 'search_cache';
  static const Duration cacheDuration = Duration(hours: 1); // 1 час

  // Получить результаты из кэша
  static Future<List<Product>?> getCachedResults(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      
      if (cacheJson == null) return null;
      
      final Map<String, dynamic> cache = jsonDecode(cacheJson);
      final key = query.toLowerCase().trim();
      
      if (!cache.containsKey(key)) return null;
      
      final entry = cache[key];
      final cachedAt = DateTime.parse(entry['cachedAt']);
      
      // Проверяем, не устарел ли кэш
      if (DateTime.now().difference(cachedAt) > cacheDuration) {
        // Кэш устарел, но всё равно вернём его как резерв
        final products = (entry['products'] as List)
            .map((p) => Product.fromMap(p))
            .toList();
        return products;
      }
      
      final products = (entry['products'] as List)
          .map((p) => Product.fromMap(p))
          .toList();
      
      return products;
    } catch (e) {
      return null;
    }
  }

  // Проверить, актуален ли кэш
  static Future<bool> isCacheFresh(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      if (cacheJson == null) return false;
      
      final Map<String, dynamic> cache = jsonDecode(cacheJson);
      final key = query.toLowerCase().trim();
      
      if (!cache.containsKey(key)) return false;
      
      final cachedAt = DateTime.parse(cache[key]['cachedAt']);
      return DateTime.now().difference(cachedAt) < cacheDuration;
    } catch (e) {
      return false;
    }
  }

  // Сохранить результаты в кэш
  static Future<void> cacheResults(String query, List<Product> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      
      Map<String, dynamic> cache = {};
      if (cacheJson != null) {
        cache = jsonDecode(cacheJson);
      }
      
      final key = query.toLowerCase().trim();
      cache[key] = {
        'products': products.map((p) => p.toMap()).toList(),
        'cachedAt': DateTime.now().toIso8601String(),
      };
      
      // Ограничиваем размер кэша (не более 50 запросов)
      if (cache.length > 50) {
        // Удаляем самые старые записи
        final sortedKeys = cache.keys.toList()
          ..sort((a, b) {
            final aTime = DateTime.parse(cache[a]['cachedAt']);
            final bTime = DateTime.parse(cache[b]['cachedAt']);
            return aTime.compareTo(bTime);
          });
        
        for (int i = 0; i < cache.length - 50; i++) {
          cache.remove(sortedKeys[i]);
        }
      }
      
      await prefs.setString(_cacheKey, jsonEncode(cache));
    } catch (e) {
      // Игнорируем ошибки кэширования
    }
  }

  // Очистить кэш
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
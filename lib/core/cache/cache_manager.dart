import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../features/search/models/product.dart';

class CacheEntry {
  final List<Product> products;
  final DateTime createdAt;
  final Duration ttl;

  CacheEntry({
    required this.products,
    required this.createdAt,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().isAfter(createdAt.add(ttl));

  Map<String, dynamic> toMap() {
    return {
      'products': products.map((p) => p.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'ttl': ttl.inSeconds,
    };
  }

  // ✅ ИСПРАВЛЕНО: безопасное чтение Map из Hive
  factory CacheEntry.fromMap(Map<dynamic, dynamic> map) {
    // Конвертируем products — каждый элемент тоже Map<dynamic, dynamic>
    final productsList = (map['products'] as List).map((p) {
      // ✅ Безопасная конвертация: Map<dynamic, dynamic> → Map<String, dynamic>
      final safeMap = Map<String, dynamic>.from(p as Map);
      return Product.fromMap(safeMap);
    }).toList();

    return CacheEntry(
      products: productsList,
      createdAt: DateTime.parse(map['createdAt'] as String),
      ttl: Duration(seconds: map['ttl'] as int),
    );
  }
}

class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // L1: RAM кэш
  final Map<String, CacheEntry> _ramCache = {};
  static const int _maxRamSize = 100;

  // L2: Дисковый кэш
  Box? _diskCache;

  // Статистика
  int _ramHits = 0;
  int _diskHits = 0;
  int _misses = 0;

  Future<void> init() async {
    try {
      _diskCache = await Hive.openBox('cache');
      debugPrint('✅ CacheManager инициализирован (Hive)');
    } catch (e) {
      debugPrint('❌ Ошибка инициализации Hive: $e');
    }
  }

  // Получить данные из кэша
  Future<List<Product>?> get(String key) async {
    // L1: RAM
    final ramEntry = _ramCache[key];
    if (ramEntry != null && !ramEntry.isExpired) {
      _ramHits++;
      debugPrint('✅ L1 кэш попадание: $key (${ramEntry.products.length} товаров)');
      return ramEntry.products;
    }

    // L2: Диск
    if (_diskCache != null) {
      try {
        final diskData = _diskCache!.get(key);
        if (diskData != null) {
          // ✅ ИСПРАВЛЕНО: diskData может быть Map<dynamic, dynamic>
          final entry = CacheEntry.fromMap(Map<dynamic, dynamic>.from(diskData as Map));
          if (!entry.isExpired) {
            _diskHits++;
            // Восстанавливаем в RAM
            _addToRamCache(key, entry);
            debugPrint('✅ L2 кэш попадание: $key (${entry.products.length} товаров)');
            return entry.products;
          } else {
            // Удаляем устаревшее
            await _diskCache!.delete(key);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Ошибка чтения из Hive: $e');
        // Удаляем битую запись
        try {
          await _diskCache!.delete(key);
        } catch (_) {}
      }
    }

    _misses++;
    debugPrint('❌ Кэш промах: $key');
    return null;
  }

  // Сохранить данные в кэш
  Future<void> set(String key, List<Product> products, {Duration? ttl}) async {
    final entry = CacheEntry(
      products: products,
      createdAt: DateTime.now(),
      ttl: ttl ?? _getDefaultTtl(key),
    );

    // L1: RAM
    _addToRamCache(key, entry);

    // L2: Диск
    if (_diskCache != null) {
      try {
        await _diskCache!.put(key, entry.toMap());
      } catch (e) {
        debugPrint('⚠️ Ошибка записи в Hive: $e');
      }
    }

    debugPrint('💾 Сохранено в кэш: $key (${products.length} товаров, TTL: ${entry.ttl.inMinutes} мин)');
  }

  // Добавить в RAM кэш с ограничением размера
  void _addToRamCache(String key, CacheEntry entry) {
    _ramCache[key] = entry;
    if (_ramCache.length > _maxRamSize) {
      _ramCache.remove(_ramCache.keys.first);
    }
  }

  // Очистить кэш
  Future<void> clear() async {
    _ramCache.clear();
    if (_diskCache != null) {
      await _diskCache!.clear();
    }
    debugPrint('🧹 Кэш очищен');
  }

  // Очистить устаревшие записи
  Future<void> cleanup() async {
    _ramCache.removeWhere((key, entry) => entry.isExpired);
    
    if (_diskCache != null) {
      try {
        final keysToDelete = <String>[];
        
        for (var key in _diskCache!.keys.toList()) {
          try {
            final value = _diskCache!.get(key);
            if (value != null) {
              final entry = CacheEntry.fromMap(Map<dynamic, dynamic>.from(value as Map));
              if (entry.isExpired) {
                keysToDelete.add(key);
              }
            }
          } catch (e) {
            keysToDelete.add(key);
          }
        }
        
        for (var key in keysToDelete) {
          await _diskCache!.delete(key);
        }
        
        if (keysToDelete.isNotEmpty) {
          debugPrint('🧹 Удалено ${keysToDelete.length} устаревших записей');
        }
      } catch (e) {
        debugPrint('⚠️ Ошибка очистки Hive: $e');
      }
    }
  }

  // TTL по умолчанию в зависимости от типа
  Duration _getDefaultTtl(String key) {
    if (key.startsWith('search:wb:')) return const Duration(hours: 1);
    if (key.startsWith('search:ozon:')) return const Duration(hours: 1);
    if (key.startsWith('search:takprodam:')) return const Duration(hours: 1);
    if (key.startsWith('category:takprodam:')) return const Duration(hours: 24);
    if (key.startsWith('promotion:takprodam:')) return const Duration(hours: 1);
    if (key.startsWith('product:wb:')) return const Duration(hours: 6);
    if (key.startsWith('product:ozon:')) return const Duration(hours: 6);
    if (key.startsWith('trends:')) return const Duration(hours: 12);
    if (key.startsWith('history:')) return const Duration(days: 30);
    return const Duration(hours: 1);
  }

  // Статистика
  void printStats() {
    final total = _ramHits + _diskHits + _misses;
    final hitRate = total > 0 ? ((_ramHits + _diskHits) / total * 100).toStringAsFixed(1) : '0';
    debugPrint('📊 Статистика кэша:');
    debugPrint('   L1 попадания: $_ramHits');
    debugPrint('   L2 попадания: $_diskHits');
    debugPrint('   Промахи: $_misses');
    debugPrint('   Hit rate: $hitRate%');
  }

  void resetStats() {
    _ramHits = 0;
    _diskHits = 0;
    _misses = 0;
  }
}
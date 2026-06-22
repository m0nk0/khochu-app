import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../../core/cache/cache_manager.dart';
import '../models/product.dart';

class TakprodamApi {
  static const String _apiToken = '5862debb-b839-4283-b761-764ef27bed34';
  static const String _baseUrl = 'https://api.takprodam.ru/v2/publisher';
  static const int _sourceId = 20239;
  
  // Умный кэш
  static final CacheManager _cache = CacheManager();

  // ==================== ПЛОЩАДКИ ====================
  
  static Future<List<Map<String, dynamic>>> getSources() async {
    const cacheKey = 'source:takprodam:list';
    
    final cached = await _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('✅ Такпродам площадки из кэша');
      return cached.map((p) => {
        'id': p.id,
        'title': p.marketplace,
        'status': 'approved',
      }).toList();
    }
    
    try {
      final url = Uri.parse('$_baseUrl/source/');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_apiToken',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('[Takprodam] Площадки статус: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['items'] != null && data['items'] is List) {
          final sources = (data['items'] as List)
              .map((item) => item as Map<String, dynamic>)
              .toList();
          
          debugPrint('[Takprodam] Найдено площадок: ${sources.length}');
          for (var source in sources) {
            debugPrint('[Takprodam] - ${source['title']} (ID: ${source['id']}, статус: ${source['status']})');
          }
          
          return sources;
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('[Takprodam] Ошибка площадок: $e');
      return [];
    }
  }

  // ==================== КАТЕГОРИИ ====================
  
  static Future<List<Map<String, dynamic>>> getCategories() async {
    const cacheKey = 'category:takprodam:all';
    
    final cached = await _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('✅ Такпродам категории из кэша (${cached.length} записей)');
      return _categoriesCache ?? [];
    }
    
    try {
      final url = Uri.parse('$_baseUrl/product-category/');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_apiToken',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('[Takprodam] Категории статус: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['items'] != null && data['items'] is List) {
          final categories = (data['items'] as List)
              .map((item) => item as Map<String, dynamic>)
              .toList();
          
          debugPrint('[Takprodam] Получено категорий: ${categories.length}');
          
          _categoriesCache = categories;
          
          return categories;
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('[Takprodam] Ошибка категорий: $e');
      return [];
    }
  }
  
  static List<Map<String, dynamic>>? _categoriesCache;

  // ==================== ТОВАРЫ ====================
  
  static Future<List<Product>> getProducts({
    int? categoryId,
    String? marketplace,
    int limit = 20,
    int page = 1,
  }) async {
    final cacheKey = 'search:takprodam:cat${categoryId ?? 0}:marketplace${marketplace ?? 'all'}:page$page:limit$limit';
    
    // Проверяем кэш
    final cached = await _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('✅ Такпродам товары из кэша: ${cached.length} товаров');
      return cached;
    }
    
    // ⏱️ ВАЖНО: Пауза перед запросом (защита от rate limit)
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      debugPrint('[Takprodam] 🔍 Получаем товары (marketplace: $marketplace, category: $categoryId)');
      
      final queryParams = {
        'source_id': _sourceId.toString(),
        'limit': limit.toString(),
        'page': page.toString(),
      };
      
      if (marketplace != null) queryParams['marketplace'] = marketplace;
      if (categoryId != null) queryParams['category_id'] = categoryId.toString();
      
      final url = Uri.parse('$_baseUrl/product/').replace(queryParameters: queryParams);

      http.Response response;
      int attempts = 0;
      const maxAttempts = 3;
      
      // 🔄 Повторные попытки при rate limit
      do {
        response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $_apiToken',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 30));

        debugPrint('[Takprodam] Товары статус: ${response.statusCode}');
        
        // Если получили 429 — ждём и повторяем
        if (response.statusCode == 429 && attempts < maxAttempts) {
          attempts++;
          final waitSeconds = 5 * attempts; // 5, 10, 15 секунд
          debugPrint('[Takprodam] ⚠️ Rate limit! Ждём $waitSeconds сек... (попытка $attempts/$maxAttempts)');
          await Future.delayed(Duration(seconds: waitSeconds));
        } else {
          break;
        }
      } while (attempts < maxAttempts);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['items'] != null && data['items'] is List && (data['items'] as List).isNotEmpty) {
          debugPrint('[Takprodam] 📦 Первый товар: ${(data['items'][0] as Map)['title']}');
        }
        
        if (data['items'] != null && data['items'] is List) {
          final items = data['items'] as List;
          debugPrint('[Takprodam] Получено товаров: ${items.length}');
          
          final products = <Product>[];
          
          for (var item in items) {
            try {
              final product = Product(
                id: item['product_id']?.toString() ?? item['id']?.toString() ?? '',
                name: item['title'] ?? 'Товар',
                price: (item['price'] as num?)?.toDouble() ?? 0,
                oldPrice: (item['old_price'] as num?)?.toDouble(),
                imageUrl: item['image_url'] ?? '',
                rating: 0,
                salesCount: 0,
                deepLink: item['external_link'] ?? '',
                marketplace: _normalizeMarketplace(item['marketplace_title'] ?? ''),
                cachedAt: DateTime.now(),
                extractionMethod: 'takprodam_api',
                trackingLink: item['tracking_link'] ?? '',
                commission: (item['commission'] as num?)?.toDouble() ?? 0,
              );
              
              products.add(product);
            } catch (e) {
              debugPrint('[Takprodam] Ошибка парсинга товара: $e');
              continue;
            }
          }
          
          // 💾 Сохраняем в кэш (даже если пусто — чтобы не спамить API)
          await _cache.set(cacheKey, products);
          
          return products;
        }
      } else if (response.statusCode == 429) {
        debugPrint('[Takprodam] ❌ Rate limit после $maxAttempts попыток. Попробуйте позже.');
      } else {
        debugPrint('[Takprodam] Ошибка товаров: ${response.body}');
      }
      
      return [];
    } catch (e, stackTrace) {
      debugPrint('[Takprodam] Ошибка получения товаров: $e');
      debugPrint('[Takprodam] Stack: $stackTrace');
      return [];
    }
  }

  // ==================== АКЦИИ ====================
  
  static Future<List<Map<String, dynamic>>> getPromotions({
    String? marketplace,
    String? promotionType,
    int limit = 50,
  }) async {
    final cacheKey = 'promotion:takprodam:list:limit$limit:marketplace${marketplace ?? 'all'}';
    
    final cached = await _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('✅ Такпродам акции из кэша (${cached.length} записей)');
      return _promotionsCache ?? [];
    }
    
    try {
      debugPrint('[Takprodam] 🎁 Получаем акции...');
      
      final queryParams = {
        'source_id': _sourceId.toString(),
        'limit': limit.toString(),
      };
      
      if (marketplace != null) queryParams['marketplace'] = marketplace;
      if (promotionType != null) queryParams['promotion_type'] = promotionType;
      
      final url = Uri.parse('$_baseUrl/promotion/').replace(queryParameters: queryParams);

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_apiToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      debugPrint('[Takprodam] Акции статус: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['items'] != null && data['items'] is List) {
          final promotions = (data['items'] as List)
              .map((item) => item as Map<String, dynamic>)
              .toList();
          
          debugPrint('[Takprodam] Получено акций: ${promotions.length}');
          for (var promo in promotions.take(5)) {
            debugPrint('[Takprodam] - ${promo['title']} (${promo['promotion_type']})');
          }
          
          _promotionsCache = promotions;
          
          return promotions;
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('[Takprodam] Ошибка акций: $e');
      return [];
    }
  }
  
  static List<Map<String, dynamic>>? _promotionsCache;

  // ==================== ТОВАРЫ АКЦИЙ ====================
  
  static Future<List<Product>> getPromotionProducts({
    required int promotionId,
    String? marketplace,
    int? categoryId,
    int limit = 30,
    int page = 1,
  }) async {
    final cacheKey = 'promotion:takprodam:promo$promotionId:page$page:limit$limit';
    
    final cached = await _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('✅ Такпродам товары акции $promotionId из кэша: ${cached.length} товаров');
      return cached;
    }
    
    try {
      debugPrint('[Takprodam] 🎁 Получаем товары из акции $promotionId');
      
      final queryParams = {
        'source_id': _sourceId.toString(),
        'promotion_id': promotionId.toString(),
        'limit': limit.toString(),
        'page': page.toString(),
      };
      
      if (marketplace != null) queryParams['marketplace'] = marketplace;
      if (categoryId != null) queryParams['category_id'] = categoryId.toString();
      
      final url = Uri.parse('$_baseUrl/promotion/product/').replace(queryParameters: queryParams);

      http.Response response;
      int attempts = 0;
      const maxAttempts = 3;
      
      // 🔄 Повторные попытки при rate limit
      do {
        response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $_apiToken',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 30));

        debugPrint('[Takprodam] Товары акции статус: ${response.statusCode}');
        
        if (response.statusCode == 429 && attempts < maxAttempts) {
          attempts++;
          final waitSeconds = 5 * attempts;
          debugPrint('[Takprodam] ⚠️ Rate limit на акции! Ждём $waitSeconds сек... (попытка $attempts/$maxAttempts)');
          await Future.delayed(Duration(seconds: waitSeconds));
        } else {
          break;
        }
      } while (attempts < maxAttempts);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['items'] != null && data['items'] is List) {
          final items = data['items'] as List;
          debugPrint('[Takprodam] Получено товаров из акции: ${items.length}');
          
          final products = <Product>[];
          
          for (var item in items) {
            try {
              final product = Product(
                id: item['product_id']?.toString() ?? item['id']?.toString() ?? '',
                name: item['title'] ?? 'Товар',
                price: (item['price'] as num?)?.toDouble() ?? 0,
                oldPrice: (item['old_price'] as num?)?.toDouble(),
                imageUrl: item['image_url'] ?? '',
                rating: 0,
                salesCount: 0,
                deepLink: item['external_link'] ?? '',
                marketplace: _normalizeMarketplace(item['marketplace_title'] ?? ''),
                cachedAt: DateTime.now(),
                extractionMethod: 'takprodam_promotion',
                trackingLink: item['tracking_link'] ?? '',
                commission: (item['commission'] as num?)?.toDouble() ?? 0,
              );
              
              products.add(product);
            } catch (e) {
              debugPrint('[Takprodam] Ошибка парсинга товара акции: $e');
              continue;
            }
          }
          
          // 💾 Сохраняем в кэш
          await _cache.set(cacheKey, products);
          
          return products;
        }
      } else if (response.statusCode == 429) {
        debugPrint('[Takprodam] ❌ Rate limit на акции после $maxAttempts попыток.');
      }
      
      return [];
    } catch (e, stackTrace) {
      debugPrint('[Takprodam] Ошибка товаров акции: $e');
      debugPrint('[Takprodam] Stack: $stackTrace');
      return [];
    }
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================
  
  static String _normalizeMarketplace(String marketplace) {
    final lower = marketplace.toLowerCase();
    if (lower.contains('wildberries') || lower.contains('wb')) {
      return 'wildberries';
    } else if (lower.contains('ozon')) {
      return 'ozon';
    } else if (lower.contains('lamoda')) {
      return 'lamoda';
    } else if (lower.contains('megamarket') || lower.contains('мегамаркет')) {
      return 'megamarket';
    } else if (lower.contains('aliexpress') || lower.contains('ali')) {
      return 'aliexpress';
    } else if (lower.contains('avito')) {
      return 'avito';
    }
    return marketplace.toLowerCase();
  }

  static Future<void> clearCache() async {
    await _cache.clear();
    _categoriesCache = null;
    _promotionsCache = null;
    debugPrint('🧹 Кэш Такпродам очищен');
  }

  static void printCacheStats() {
    _cache.printStats();
  }
}
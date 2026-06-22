import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../../core/cache/cache_manager.dart';
import '../models/product.dart';

class BhApiService {
  static const String _baseUrl = 'https://bhapi.ru';
  static const String _apiToken = 'Gc_GmTkr2M9-XaLIOmLDTCpKGGINnATiDwQP3QxVTnY';
  static final CacheManager _cache = CacheManager();

  // Поиск товаров по WB (БЕЗ картинок - быстро)
  static Future<List<Product>> searchWbProducts(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    final cacheKey = 'search:wb:$query:page$page:limit$limit';

    // Проверяем кэш
    final cached = await _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('✅ WB поиск из кэша: "$query" (${cached.length} товаров)');
      return cached;
    }

    debugPrint('🔍 WB поиск через BHAPI: "$query" (страница $page, лимит $limit)');

    try {
      final url = Uri.parse('$_baseUrl/wb/api/v1/search').replace(
        queryParameters: {
          'q': query,
          'page': page.toString(),
          'max_links': limit.toString(),
        },
      );

      final response = await http.get(
        url,
        headers: {
          'X-API-Token': _apiToken,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      debugPrint('[BHAPI] Статус: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'ok' && data['data'] != null) {
          final searchData = data['data'];
          final products = <Product>[];

          if (searchData['products'] != null && searchData['products'] is List) {
            for (var item in searchData['products']) {
              try {
                final price = (item['price'] as num?)?.toDouble() ?? 0;
                
                final product = Product(
                  id: item['id']?.toString() ?? '',
                  name: item['description'] ?? 'Товар WB',
                  price: price,
                  imageUrl: '', // Картинки нет в поисковом ответе
                  rating: (item['rating'] as num?)?.toDouble() ?? 0,
                  salesCount: (item['feedbacks'] as num?)?.toInt() ?? 0,
                  deepLink: item['link'] ?? '',
                  marketplace: 'wildberries',
                  cachedAt: DateTime.now(),
                  extractionMethod: 'bhapi_search',
                );

                products.add(product);
              } catch (e) {
                debugPrint('[BHAPI] Ошибка парсинга товара: $e');
                continue;
              }
            }
          }

          debugPrint('[BHAPI] Найдено товаров: ${products.length}');

          // Сохраняем в кэш
          await _cache.set(cacheKey, products);

          return products;
        }
      } else if (response.statusCode == 429) {
        debugPrint('[BHAPI] ⚠️ Rate limit! Подождите...');
      }

      return [];
    } catch (e, stackTrace) {
      debugPrint('[BHAPI] Ошибка поиска: $e');
      debugPrint('[BHAPI] Stack: $stackTrace');
      return [];
    }
  }

  // Получить детали товара (С картинками) - для будущего использования
  static Future<Product?> getWbProductDetails(String productUrl) async {
    final cacheKey = 'product:wb:$productUrl';

    // Проверяем кэш
    final cached = await _cache.get(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      debugPrint('✅ WB детали из кэша');
      return cached.first;
    }

    debugPrint('🔍 WB детали через BHAPI');

    try {
      final url = Uri.parse('$_baseUrl/wb/api/v1/item/by-url').replace(
        queryParameters: {
          'url': productUrl,
        },
      );

      final response = await http.get(
        url,
        headers: {
          'X-API-Token': _apiToken,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'ok' && data['data'] != null) {
          final itemData = data['data']['data'];

          final product = Product(
            id: itemData['item_id']?.toString() ?? '',
            name: itemData['title'] ?? 'Товар WB',
            price: 0, // price_info может быть пустым
            imageUrl: itemData['main_imgs'] != null && itemData['main_imgs'].isNotEmpty
                ? itemData['main_imgs'][0]
                : '',
            rating: 0,
            salesCount: 0,
            deepLink: itemData['product_url'] ?? productUrl,
            marketplace: 'wildberries',
            cachedAt: DateTime.now(),
            extractionMethod: 'bhapi_details',
          );

          // Сохраняем в кэш (TTL 24 часа - картинки меняются редко)
          await _cache.set(cacheKey, [product], ttl: const Duration(hours: 24));

          return product;
        }
      }

      return null;
    } catch (e) {
      debugPrint('[BHAPI] Ошибка получения деталей: $e');
      return null;
    }
  }
}
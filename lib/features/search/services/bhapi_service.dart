import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../../core/cache/cache_manager.dart';
import '../models/product.dart';

class BhApiService {
  static const String _baseUrl = 'https://bhapi.ru';
  static const String _apiToken = 'Gc_GmTkr2M9-XaLIOmLDTCpKGGINnATiDwQP3QxVTnY';
  static final CacheManager _cache = CacheManager();

  static Future<List<Product>> searchWbProducts(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    final cacheKey = 'search:wb:$query:page$page:limit$limit';

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

      http.Response? response;
      for (var attempt = 1; attempt <= 3; attempt++) {
        try {
          debugPrint('[BHAPI] Попытка $attempt из 3...');
          response = await http.get(
            url,
            headers: {
              'X-API-Token': _apiToken,
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 60));
          
          if ((response.statusCode == 429 || response.statusCode == 503) && attempt < 3) {
            final waitSeconds = response.statusCode == 503 ? attempt * 10 : attempt * 3;
            debugPrint('[BHAPI] ⚠️ HTTP ${response.statusCode}! Ждём $waitSeconds сек...');
            await Future.delayed(Duration(seconds: waitSeconds));
            continue;
          }
          break;
        } catch (e) {
          debugPrint('[BHAPI] ⚠️ Попытка $attempt не удалась: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt * 5));
          } else {
            rethrow;
          }
        }
      }

      debugPrint('[BHAPI] Статус: ${response!.statusCode}');

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
                  imageUrl: '',
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
          _cache.set(cacheKey, products);
          return products;
        }
      } else if (response.statusCode == 503) {
        debugPrint('[BHAPI] ❌ BHAPI временно недоступен (503).');
        throw Exception('Сервис WB временно недоступен. Попробуйте позже.');
      } else if (response.statusCode == 429) {
        debugPrint('[BHAPI] ❌ Rate limit (429) — все попытки исчерпаны');
        throw Exception('Слишком много запросов. Подождите минуту.');
      }

      return [];
    } catch (e, stackTrace) {
      debugPrint('[BHAPI] Ошибка поиска: $e');
      rethrow;
    }
  }

  static Future<Product?> getWbProductDetails(String productUrl) async {
    final cacheKey = 'product:wb:$productUrl';

    final cached = await _cache.get(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      debugPrint('✅ WB детали из кэша');
      return cached.first;
    }

    try {
      final url = Uri.parse('$_baseUrl/wb/api/v1/item/by-url').replace(
        queryParameters: {
          'url': productUrl,
        },
      );

      http.Response? response;
      for (var attempt = 1; attempt <= 3; attempt++) {
        try {
          response = await http.get(
            url,
            headers: {
              'X-API-Token': _apiToken,
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 60));
          
          if ((response.statusCode == 429 || response.statusCode == 503) && attempt < 3) {
            final waitSeconds = response.statusCode == 503 ? attempt * 5 : attempt * 3;
            debugPrint('[BHAPI] ⚠️ HTTP ${response.statusCode} для деталей. Ждём $waitSeconds сек...');
            await Future.delayed(Duration(seconds: waitSeconds));
            continue;
          }
          break;
        } catch (e) {
          debugPrint('[BHAPI] ⚠️ Попытка $attempt не удалась: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt * 2));
          } else {
            return null;
          }
        }
      }

      if (response!.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'ok' && data['data'] != null) {
          final itemData = data['data']['data'];
          
          if (itemData == null) return null;
          
          final hasImages = itemData['main_imgs'] != null && 
                            itemData['main_imgs'] is List && 
                            (itemData['main_imgs'] as List).isNotEmpty;
          
          if (hasImages) {
            // 🆕 Парсим цену из price_info
            double price = 0;
            if (itemData['price_info'] != null) {
              final priceInfo = itemData['price_info'];
              if (priceInfo['price'] != null) {
                price = (priceInfo['price'] as num?)?.toDouble() ?? 0;
              } else if (priceInfo['salePrice'] != null) {
                price = (priceInfo['salePrice'] as num?)?.toDouble() ?? 0;
              } else if (priceInfo is num) {
                price = priceInfo.toDouble();
              }
            }
            
            final product = Product(
              id: itemData['item_id']?.toString() ?? '',
              name: itemData['title'] ?? 'Товар WB',
              price: price,  // ← ТЕПЕРЬ С ЦЕНОЙ!
              imageUrl: itemData['main_imgs'][0],
              rating: 0,
              salesCount: 0,
              deepLink: itemData['product_url'] ?? productUrl,
              marketplace: 'wildberries',
              cachedAt: DateTime.now(),
              extractionMethod: 'bhapi_details',
            );

            _cache.set(cacheKey, [product], ttl: const Duration(hours: 24));
            debugPrint('[BHAPI] ✅ Картинка загружена: ${product.imageUrl}');
            return product;
          }
        }
      } else if (response.statusCode == 429 || response.statusCode == 503) {
        debugPrint('[BHAPI] ❌ HTTP ${response.statusCode} — все попытки исчерпаны');
      }

      return null;
    } catch (e) {
      debugPrint('[BHAPI] ❌ Ошибка для $productUrl: $e');
      return null;
    }
  }
}
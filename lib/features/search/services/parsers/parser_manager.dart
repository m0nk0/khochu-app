import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../cache_service.dart';
import '../rate_limiter.dart';
import 'wb_api_parser.dart';
import 'ozon_parser.dart';
import 'megamarket_parser.dart';

enum SortType { priceAsc, priceDesc, rating, popularity }

class SearchResult {
  final List<Product> products;
  final bool fromCache;
  final bool isFresh;

  SearchResult({
    required this.products,
    required this.fromCache,
    required this.isFresh,
  });
}

class ParserManager {
  final WbApiParser _wbApiParser = WbApiParser();
  final OzonParser _ozonParser = OzonParser();
  final MegamarketParser _megamarketParser = MegamarketParser(); // ← НОВЫЙ ПАРСЕР
  final RateLimiter _rateLimiter = RateLimiter(
    minInterval: const Duration(seconds: 60),
  );

  Future<SearchResult> searchAll(
    String query, {
    SortType sortType = SortType.priceAsc,
    bool forceRefresh = false,
  }) async {
    debugPrint('🔍 Начинаем поиск: $query (forceRefresh=$forceRefresh)');

    // 1. Проверяем кэш
    if (!forceRefresh) {
      final cached = await CacheService.getCachedResults(query);
      final isFresh = await CacheService.isCacheFresh(query);

      if (cached != null && cached.isNotEmpty) {
        debugPrint('✅ Берём из кэша: ${cached.length} товаров (свежесть: $isFresh)');
        return SearchResult(
          products: _sortProducts(cached, sortType),
          fromCache: true,
          isFresh: isFresh,
        );
      }
    }

    // 2. Кэша нет — делаем запросы
    await _rateLimiter.waitForPermission();

    final List<List<Product>> results = await Future.wait<List<Product>>([
      // WB временно отключён (бан)
      Future.value(<Product>[]),
      
      _ozonParser.search(query).catchError((e) {
        debugPrint('❌ Ozon парсинг ошибка: $e');
        return <Product>[];
      }),
      _megamarketParser.search(query).catchError((e) {
        debugPrint('❌ Megamarket парсинг ошибка: $e');
        return <Product>[];
      }),
    ]);

    final wbProducts = results[0];
    final ozonProducts = results[1];
    final megamarketProducts = results[2];

    debugPrint('✅ WB найдено: ${wbProducts.length} товаров');
    debugPrint('✅ Ozon найдено: ${ozonProducts.length} товаров');
    debugPrint('✅ Megamarket найдено: ${megamarketProducts.length} товаров');

    final allProducts = [...wbProducts, ...ozonProducts, ...megamarketProducts];

    // 3. Если ничего не нашли — пробуем кэш как резерв
    if (allProducts.isEmpty) {
      debugPrint('⚠️ Ничего не найдено, пробуем кэш как резерв');
      final cached = await CacheService.getCachedResults(query);
      if (cached != null && cached.isNotEmpty) {
        return SearchResult(
          products: _sortProducts(cached, sortType),
          fromCache: true,
          isFresh: false,
        );
      }
      return SearchResult(products: [], fromCache: false, isFresh: false);
    }

    // 4. Сохраняем в кэш
    await CacheService.cacheResults(query, allProducts);

    return SearchResult(
      products: _sortProducts(allProducts, sortType),
      fromCache: false,
      isFresh: true,
    );
  }

  List<Product> _sortProducts(List<Product> products, SortType sortType) {
    final sorted = List<Product>.from(products);
    switch (sortType) {
      case SortType.priceAsc:
        sorted.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortType.priceDesc:
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortType.rating:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SortType.popularity:
        sorted.sort((a, b) => b.salesCount.compareTo(a.salesCount));
        break;
    }
    return sorted;
  }
}
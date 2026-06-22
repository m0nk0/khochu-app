import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../models/product.dart';

class LamodaParser {
  static const String _searchUrl = 'https://www.lamoda.ru/catalog/search/';
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 5);

  Future<List<Product>> search(String query) async {
    try {
      debugPrint('[Lamoda] 🔍 Начинаем поиск: $query');

      final uri = Uri.parse(_searchUrl).replace(queryParameters: {
        'q': query,
      });

      debugPrint('[Lamoda] URL: $uri');

      http.Response? response;
      for (int attempt = 1; attempt <= _maxRetries; attempt++) {
        response = await http.get(
          uri,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
            'Referer': 'https://www.lamoda.ru/',
          },
        );

        debugPrint('[Lamoda] Статус: ${response.statusCode}');

        if (response.statusCode == 200) {
          break;
        } else if (response.statusCode == 429 || response.statusCode == 403) {
          if (attempt < _maxRetries) {
            debugPrint('[Lamoda] Получили ${response.statusCode}, ждём...');
            await Future.delayed(_retryDelay);
          } else {
            return [];
          }
        } else {
          debugPrint('[Lamoda] Ошибка: ${response.statusCode}');
          return [];
        }
      }

      if (response == null || response.statusCode != 200) {
        return [];
      }

      final html = response.body;

      // 🔎 Ищем __NEXT_DATA__ в HTML
      final nextDataMatch = RegExp(
        r'<script id="__NEXT_DATA__" type="application/json">(.+?)</script>',
        dotAll: true,
      ).firstMatch(html);

      if (nextDataMatch == null) {
        debugPrint('[Lamoda] ❌ Не найден __NEXT_DATA__');
        debugPrint('[Lamoda] HTML (первые 500): ${html.substring(0, html.length > 500 ? 500 : html.length)}');
        return [];
      }

      final nextDataJson = nextDataMatch.group(1)!;
      final data = jsonDecode(nextDataJson);

      debugPrint('[Lamoda] 📦 Корневые ключи __NEXT_DATA__:');
      debugPrint('[Lamoda] ${jsonEncode(data.keys.toList())}');

      // 🔎 Пытаемся найти товары в разных возможных местах
      List? products;

      if (data['props']?['pageProps']?['products'] != null) {
        products = data['props']['pageProps']['products'] as List;
        debugPrint('[Lamoda] ✅ Нашли товары в props.pageProps.products');
      } else if (data['props']?['pageProps']?['catalogProducts'] != null) {
        products = data['props']['pageProps']['catalogProducts'] as List;
        debugPrint('[Lamoda] ✅ Нашли товары в props.pageProps.catalogProducts');
      } else if (data['props']?['pageProps']?['initialState']?['products'] != null) {
        products = data['props']['pageProps']['initialState']['products'] as List;
        debugPrint('[Lamoda] ✅ Нашли товары в initialState.products');
      } else if (data['props']?['pageProps']?['searchResults']?['products'] != null) {
        products = data['props']['pageProps']['searchResults']['products'] as List;
        debugPrint('[Lamoda] ✅ Нашли товары в searchResults.products');
      }

      if (products == null || products.isEmpty) {
        debugPrint('[Lamoda] ❌ Не нашли товары. Логируем структуру...');
        _logStructure(data, 0, 3);
        return [];
      }

      debugPrint('[Lamoda] 📊 Получено ${products.length} товаров');

      // 🔍 ЛОГИРУЕМ ПЕРВЫЙ ТОВАР ЦЕЛИКОМ
      if (products.isNotEmpty) {
        debugPrint('[Lamoda] 📦 Первый товар целиком:');
        final firstProductJson = jsonEncode(products[0]);
        debugPrint('[Lamoda] $firstProductJson');
      }

      // Пока возвращаем пустой список — сначала увидим структуру
      return [];

    } catch (e, stackTrace) {
      debugPrint('[Lamoda] ❌ Ошибка: $e');
      debugPrint('[Lamoda] Stack: $stackTrace');
      return [];
    }
  }

  void _logStructure(dynamic data, int depth, int maxDepth) {
    if (depth >= maxDepth) return;
    if (data is Map) {
      for (var key in data.keys.take(10)) {
        debugPrint('[Lamoda] ${'  ' * depth}$key: ${data[key].runtimeType}');
        _logStructure(data[key], depth + 1, maxDepth);
      }
    } else if (data is List && data.isNotEmpty) {
      debugPrint('[Lamoda] ${'  ' * depth}[0]: ${data[0].runtimeType}');
      _logStructure(data[0], depth + 1, maxDepth);
    }
  }
}
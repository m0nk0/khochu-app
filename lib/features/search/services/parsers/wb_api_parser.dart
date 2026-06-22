import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../models/product.dart';

class WbApiParser {
  static const String _baseUrl = 'https://search.wb.ru/exactmatch/ru/common/v4/search';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 10);

  Future<List<Product>> search(String query) async {
    try {
      debugPrint('[WB API] Начинаем поиск: $query');

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'appType': '1',
        'curr': 'rub',
        'dest': '-1257786',
        'spp': '30',
        'query': query,
        'resultset': 'catalog',
        'sort': 'popular',
        'suppressSpellcheck': 'false',
      });

      debugPrint('[WB API] URL: $uri');

      http.Response? response;
      for (int attempt = 1; attempt <= _maxRetries; attempt++) {
        debugPrint('[WB API] Попытка $attempt из $_maxRetries');
        
        response = await http.get(
          uri,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'application/json',
            'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
            'Origin': 'https://www.wildberries.ru',
            'Referer': 'https://www.wildberries.ru/',
          },
        );

        debugPrint('[WB API] Статус: ${response.statusCode}');

        if (response.statusCode == 200) {
          break;
        } else if (response.statusCode == 429) {
          if (attempt < _maxRetries) {
            debugPrint('[WB API] Получили 429, ждём ${_retryDelay.inSeconds} секунд...');
            await Future.delayed(_retryDelay);
          } else {
            debugPrint('[WB API] Превышено максимальное количество попыток');
            return [];
          }
        } else {
          debugPrint('[WB API] Ошибка: ${response.statusCode}');
          return [];
        }
      }

      if (response == null || response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      
      List? items;
      
      if (data['data'] != null && data['data']['products'] != null) {
        items = data['data']['products'] as List;
        debugPrint('[WB API] Нашли товары в data.data.products');
      } else if (data['products'] != null) {
        items = data['products'] as List;
        debugPrint('[WB API] Нашли товары в data.products');
      } else if (data['data'] is List) {
        items = data['data'] as List;
        debugPrint('[WB API] Нашли товары в data.data (список)');
      }
      
      if (items == null || items.isEmpty) {
        debugPrint('[WB API] Нет товаров. Ключи: ${data.keys.toList()}');
        return [];
      }

      debugPrint('[WB API] Получено ${items.length} товаров');

      final products = <Product>[];

      for (var item in items.take(15)) {
        try {
          final id = item['id'] as int;
          final root = item['root'] as int? ?? id;
          
          // === ЦЕНА ===
          double price = 0;
          double? oldPrice;
          
          // Цена лежит в sizes[0].price.product (в копейках)
          if (item['sizes'] != null && item['sizes'] is List && (item['sizes'] as List).isNotEmpty) {
            final firstSize = item['sizes'][0];
            if (firstSize['price'] != null) {
              final priceObj = firstSize['price'];
              if (priceObj['product'] != null) {
                price = (priceObj['product'] as int) / 100;
              }
              if (priceObj['basic'] != null) {
                final basic = (priceObj['basic'] as int) / 100;
                if (basic > price) {
                  oldPrice = basic;
                }
              }
            }
          }
          
          // === КАРТИНКА ===
          final imageUrl = _buildImageUrl(root);
          
          // === ССЫЛКА ===
          final deepLink = 'https://www.wildberries.ru/catalog/$id/detail.aspx';
          
          products.add(Product(
            id: 'wb_$id',
            name: item['name'] ?? 'Товар WB',
            price: price,
            oldPrice: oldPrice,
            imageUrl: imageUrl,
            rating: (item['rating'] ?? 0).toDouble(),
            salesCount: item['feedbacks'] ?? 0,
            deepLink: deepLink,
            marketplace: 'wildberries',
            cachedAt: DateTime.now(),
            extractionMethod: 'api',
          ));
        } catch (e) {
          debugPrint('[WB API] Ошибка парсинга товара: $e');
          continue;
        }
      }

      debugPrint('[WB API] Найдено ${products.length} товаров');
      return products;

    } catch (e, stackTrace) {
      debugPrint('[WB API] Ошибка: $e');
      debugPrint('[WB API] Stack: $stackTrace');
      return [];
    }
  }

  String _buildImageUrl(int rootId) {
    // Используем root ID для определения корзины
    final vol = rootId ~/ 100000;
    final part = rootId ~/ 100;
    
    // Универсальная формула для определения корзины
    final basket = ((vol - 1) ~/ 54) + 1;
    final basketStr = basket.toString().padLeft(2, '0');
    
    return 'https://basket-$basketStr.wb.ru/vol$vol/part$part/$rootId/images/big/1.jpg';
  }
}
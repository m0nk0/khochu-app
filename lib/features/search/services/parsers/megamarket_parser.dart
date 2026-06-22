import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/product.dart';
import 'js_scripts.dart';

class MegamarketParser {
  static const String _searchUrl = 'https://megamarket.ru/catalog/?q=';
  static const String _channelName = 'flutter_megamarket_handler';

  Future<List<Product>> search(String query) async {
    String? receivedJsonData;

    // 1. Создаём WebView контроллер
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      )
      ..addJavaScriptChannel(
        _channelName,
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('[Megamarket] Получены данные через channel: ${message.message.length} символов');
          receivedJsonData = message.message;
        },
      );

    // 2. Добавляем NavigationDelegate
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (String url) {
          debugPrint('[Megamarket] Страница загружена: $url');
          controller.runJavaScript(JsScripts.megamarketJsonInterceptor);
        },
      ),
    );

    // 3. Загружаем страницу поиска
    controller.loadRequest(Uri.parse('$_searchUrl${Uri.encodeComponent(query)}'));

    // 4. Ждём загрузки (Мегамаркет грузится долго)
    await Future.delayed(const Duration(seconds: 8));

    // 5. Если JSON пришёл через channel — используем его
    if (receivedJsonData != null && receivedJsonData!.isNotEmpty) {
      debugPrint('[Megamarket] Используем перехваченный JSON');
      final result = _parseInterceptedJson(receivedJsonData!);
      if (result.isNotEmpty) return result;
    }

    // 6. Fallback: DOM-парсинг
    debugPrint('[Megamarket] Fallback на DOM-парсинг');
    final result = await controller.runJavaScriptReturningResult(JsScripts.megamarketSearchScript);
    return _parseJsonResult(result);
  }

  List<Product> _parseJsonResult(dynamic rawResult) {
    try {
      String jsonString = rawResult.toString();
      
      if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
        jsonString = jsonString.substring(1, jsonString.length - 1);
        jsonString = jsonString.replaceAll(r'\"', '"');
      }

      debugPrint('JSON для парсинга (первые 200 символов): ${jsonString.substring(0, jsonString.length > 200 ? 200 : jsonString.length)}');

      dynamic decoded = jsonDecode(jsonString);
      
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }

      if (decoded is! List) {
        debugPrint('Ожидался список, получено: ${decoded.runtimeType}');
        return [];
      }

      return decoded.map((json) {
        final map = json as Map<String, dynamic>;
        return Product(
          id: map['id'] ?? '',
          name: map['name'] ?? '',
          price: (map['price'] as num?)?.toDouble() ?? 0,
          imageUrl: map['imageUrl'] ?? '',
          rating: (map['rating'] as num?)?.toDouble() ?? 0,
          salesCount: (map['salesCount'] as num?)?.toInt() ?? 0,
          deepLink: map['deepLink'] ?? '',
          marketplace: map['marketplace'] ?? 'megamarket',
          cachedAt: DateTime.now(),
          extractionMethod: 'selector',
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('Ошибка парсинга JSON: $e');
      debugPrint('Stack: $stackTrace');
      return [];
    }
  }

  List<Product> _parseInterceptedJson(String jsonString) {
    try {
      final data = jsonDecode(jsonString);
      final products = <Product>[];

      // Пробуем разные структуры ответа Мегамаркета
      List? items;
      
      if (data is Map) {
        // Структура 1: data.items
        if (data['items'] != null && data['items'] is List) {
          items = data['items'] as List;
          debugPrint('[Megamarket] Нашли товары в data.items');
        }
        // Структура 2: data.data.items
        else if (data['data'] != null && data['data']['items'] != null) {
          items = data['data']['items'] as List;
          debugPrint('[Megamarket] Нашли товары в data.data.items');
        }
        // Структура 3: data.products
        else if (data['products'] != null && data['products'] is List) {
          items = data['products'] as List;
          debugPrint('[Megamarket] Нашли товары в data.products');
        }
        // Структура 4: data.catalog.products
        else if (data['catalog'] != null && data['catalog']['products'] != null) {
          items = data['catalog']['products'] as List;
          debugPrint('[Megamarket] Нашли товары в data.catalog.products');
        }
      }

      if (items == null || items.isEmpty) {
        debugPrint('[Megamarket] Не удалось извлечь товары из перехваченного JSON');
        debugPrint('[Megamarket] Ключи: ${data is Map ? data.keys.toList() : "не Map"}');
        return [];
      }

      for (var item in items.take(15)) {
        try {
          final id = item['id'] ?? item['itemId'] ?? item['productId'] ?? 'mm_${DateTime.now().millisecondsSinceEpoch}';
          final name = item['title'] ?? item['name'] ?? 'Товар Мегамаркет';
          
          // Цена может быть в разных полях
          int price = 0;
          if (item['price'] != null) {
            if (item['price'] is Map) {
              price = ((item['price']['value'] ?? item['price']['amount'] ?? 0) as num).toInt();
              // Если цена в копейках
              if (price > 100000) price = price ~/ 100;
            } else {
              price = (item['price'] as num).toInt();
              if (price > 100000) price = price ~/ 100;
            }
          } else if (item['salePrice'] != null) {
            price = (item['salePrice'] as num).toInt();
            if (price > 100000) price = price ~/ 100;
          }
          
          // Картинка
          String imageUrl = '';
          if (item['image'] != null) {
            if (item['image'] is String) {
              imageUrl = item['image'];
            } else if (item['image'] is Map) {
              imageUrl = item['image']['href'] ?? item['image']['url'] ?? '';
            }
          } else if (item['images'] != null && item['images'] is List && item['images'].isNotEmpty) {
            final firstImg = item['images'][0];
            imageUrl = firstImg is String ? firstImg : (firstImg['href'] ?? firstImg['url'] ?? '');
          }
          
          if (!imageUrl.startsWith('http')) {
            imageUrl = 'https:$imageUrl';
          }
          
          // Ссылка
          String deepLink = '';
          if (item['link'] != null) {
            deepLink = item['link'];
          } else if (item['url'] != null) {
            deepLink = item['url'];
          } else {
            deepLink = 'https://megamarket.ru/catalog/details/$id/';
          }
          if (!deepLink.startsWith('http')) {
            deepLink = 'https://megamarket.ru$deepLink';
          }
          
          // Рейтинг
          double rating = 0;
          if (item['rating'] != null) {
            rating = (item['rating'] as num).toDouble();
          } else if (item['reviewRating'] != null) {
            rating = (item['reviewRating'] as num).toDouble();
          }
          
          // Отзывы
          int salesCount = 0;
          if (item['reviews'] != null) {
            salesCount = (item['reviews'] as num).toInt();
          } else if (item['feedbacks'] != null) {
            salesCount = (item['feedbacks'] as num).toInt();
          }

          if (price > 0) {
            products.add(Product(
              id: 'mm_$id',
              name: name.toString(),
              price: price.toDouble(),
              imageUrl: imageUrl,
              rating: rating,
              salesCount: salesCount,
              deepLink: deepLink,
              marketplace: 'megamarket',
              cachedAt: DateTime.now(),
              extractionMethod: 'json',
            ));
          }
        } catch (e) {
          debugPrint('[Megamarket] Ошибка парсинга товара: $e');
          continue;
        }
      }

      debugPrint('[Megamarket] Найдено ${products.length} товаров из перехваченного JSON');
      return products;
    } catch (e) {
      debugPrint('[Megamarket] Ошибка парсинга перехваченного JSON: $e');
      return [];
    }
  }
}
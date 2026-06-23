import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/product.dart';
import 'base_parser.dart';
import 'js_scripts.dart';

class OzonParser extends BaseParser {
  @override
  String get searchUrl => 'https://www.ozon.ru/search/?text=';
  
  @override
  String get jsInterceptor => JsScripts.ozonJsonInterceptor;
  
  @override
  String get jsFallbackScript => JsScripts.ozonSearchScript;
  
  @override
  String get marketplaceName => 'Ozon';
  
  @override
  String get channelName => 'flutter_ozon_handler';

  // 🆕 ГЛАВНЫЙ МЕТОД: загружаем 3 страницы подряд
  @override
  Future<List<Product>> search(String query, {int page = 1}) async {
    final allProducts = <Product>[];
    final seenLinks = <String>{};
    
    // 🆕 Загружаем 3 страницы подряд
    for (var i = 0; i < 3; i++) {
      final currentPage = page + i;
      debugPrint('[Ozon] 📄 Загружаем страницу $currentPage...');
      
      final products = await _searchSinglePage(query, currentPage);
      
      // Добавляем только уникальные товары
      for (var product in products) {
        if (!seenLinks.contains(product.deepLink)) {
          seenLinks.add(product.deepLink);
          allProducts.add(product);
        }
      }
      
      debugPrint('[Ozon] 📊 Страница $currentPage: найдено ${products.length}, всего уникальных: ${allProducts.length}');
      
      // Если на странице мало товаров — дальше нет смысла грузить
      if (products.length < 5) {
        debugPrint('[Ozon] ⏹️ На странице $currentPage мало товаров, останавливаемся');
        break;
      }
    }
    
    debugPrint('[Ozon] ✅ ИТОГО: ${allProducts.length} уникальных товаров');
    return allProducts;
  }

  // 🆕 ВСПОМОГАТЕЛЬНЫЙ: загрузка одной страницы
  Future<List<Product>> _searchSinglePage(String query, int page) async {
    final resultCompleter = Completer<String>();

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );

    controller.addJavaScriptChannel(
      'flutter_ozon_result',
      onMessageReceived: (JavaScriptMessage message) {
        debugPrint('[Ozon] 📨 Получен результат из JS: ${message.message.length} символов');
        if (!resultCompleter.isCompleted) {
          resultCompleter.complete(message.message);
        }
      },
    );

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (String url) {
          debugPrint('[$marketplaceName] Страница $page загружена');
        },
      ),
    );

    final encodedQuery = Uri.encodeComponent(query);
    final url = 'https://www.ozon.ru/search/?text=$encodedQuery&page=$page';
    
    controller.loadRequest(Uri.parse(url));

    // Ждём первичную загрузку
    await Future.delayed(const Duration(seconds: 5));

    // Запускаем JS-скрипт
    await controller.runJavaScript(jsFallbackScript);
    
    // Ждём результат с таймаутом
    String jsonString;
    try {
      jsonString = await resultCompleter.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('[Ozon] ⏱️ Таймаут на странице $page');
          return '[]';
        },
      );
    } catch (e) {
      debugPrint('[Ozon] ❌ Ошибка на странице $page: $e');
      jsonString = '[]';
    }
    
    return _parseJsonResult(jsonString);
  }

  List<Product> _parseJsonResult(dynamic rawResult) {
    try {
      String jsonString = rawResult.toString();
      
      if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
        jsonString = jsonString.substring(1, jsonString.length - 1);
        jsonString = jsonString.replaceAll(r'\"', '"');
        jsonString = jsonString.replaceAll(r'\\', '');
      }

      dynamic decoded = jsonDecode(jsonString);
      
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }

      if (decoded is! List) {
        debugPrint('[Ozon] Ожидался список, получено: ${decoded.runtimeType}');
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
          marketplace: map['marketplace'] ?? 'ozon',
          cachedAt: DateTime.now(),
          extractionMethod: 'selector',
        );
      }).toList();
    } catch (e) {
      debugPrint('[Ozon] Ошибка парсинга JSON: $e');
      return [];
    }
  }
}
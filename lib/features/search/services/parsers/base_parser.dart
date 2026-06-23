import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/product.dart';
import 'js_scripts.dart';

abstract class BaseParser {
  String get searchUrl;
  String get jsInterceptor;
  String get jsFallbackScript;
  String get marketplaceName;
  String get channelName;

  Future<List<Product>> search(String query, {int page = 1}) async {
    String? receivedJsonData;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      )
      ..addJavaScriptChannel(
        channelName,
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('[$marketplaceName] Получены данные через channel: ${message.message.length} символов');
          receivedJsonData = message.message;
        },
      );

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (String url) {
          debugPrint('[$marketplaceName] Страница загружена: $url');
          controller.runJavaScript(jsInterceptor);
        },
      ),
    );

    String finalUrl = '$searchUrl${Uri.encodeComponent(query)}';
    
    if (page > 1) {
      if (finalUrl.contains('?')) {
        finalUrl += '&page=$page';
      } else {
        finalUrl += '?page=$page';
      }
    }
    
    debugPrint('[$marketplaceName] Загружаем URL: $finalUrl');
    controller.loadRequest(Uri.parse(finalUrl));

    await Future.delayed(const Duration(seconds: 8));

    if (receivedJsonData != null && receivedJsonData!.isNotEmpty) {
      debugPrint('[$marketplaceName] Используем перехваченный JSON');
      final result = _parseInterceptedJson(receivedJsonData!);
      if (result.isNotEmpty) return result;
    }

    debugPrint('[$marketplaceName] Fallback на DOM-парсинг');
    final result = await controller.runJavaScriptReturningResult(jsFallbackScript);
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
          marketplace: map['marketplace'] ?? '',
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

      if (data is Map && data['data'] != null && data['data']['products'] != null) {
        final items = data['data']['products'] as List;
        for (var item in items.take(25)) {
          final id = item['id'];
          products.add(Product(
            id: 'wb_$id',
            name: item['name'] ?? 'Товар WB',
            price: ((item['salePriceU'] ?? item['priceU'] ?? 0) as num) / 100,
            imageUrl: 'https://basket-01.wb.ru/vol${(id as int) ~/ 100000}/part${id ~/ 100}/$id/images/big/1.jpg',
            rating: (item['rating'] ?? 0).toDouble(),
            salesCount: item['sale'] ?? 0,
            deepLink: 'https://www.wildberries.ru/catalog/$id/detail.aspx',
            marketplace: 'wildberries',
            cachedAt: DateTime.now(),
            extractionMethod: 'json',
          ));
        }
      }

      return products;
    } catch (e) {
      debugPrint('Ошибка парсинга перехваченного JSON: $e');
      return [];
    }
  }
}
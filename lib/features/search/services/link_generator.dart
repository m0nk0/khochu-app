import '../models/search_config.dart';

class LinkGenerator {
  static Map<String, dynamic> parseQuery(String query) {
    // 1. Извлекаем цену
    final regexPrice = RegExp(
      r'(?:до|не дороже|меньше|дешевле|недорого|max)?\s*(\d{3,5})\s*(?:рублей?|₽|р\.?)?', 
      caseSensitive: false
    );
    final match = regexPrice.firstMatch(query);
    final maxPrice = match != null ? double.tryParse(match.group(1)!) : null;

    // 2. Список стоп-слов (расширенный)
    final stopWords = RegExp(
      r'\b(найди|найти|покажи|хочу|купить|где|нужен|нужна|нужно|посоветуй|подбери|пожалуйста|please|мне|давай|тут|есть|рублей?|₽|р)\b',
      caseSensitive: false
    );
    
    // 3. Очистка
    String cleanQuery = query
        .replaceAll(stopWords, ' ') 
        .replaceAll(RegExp(r'\b(до|не дороже|меньше|дешевле|недорого|max)\b', caseSensitive: false), ' ') 
        .replaceAll(RegExp(r'\b\d{3,5}\b'), ' ') 
        .replaceAll(RegExp(r'\s+'), ' ') 
        .trim();

    // 4. 🔥 ВАЖНОЕ ИСПРАВЛЕНИЕ: Чистка "хвостов"
    // Если в конце осталось короткое слово (1-2 буквы), которое не является размером (S, M, L, XL) или брендом, удаляем его.
    // Это спасает от запросов типа "носки лей" или "футболка р".
    final trailingGarbage = RegExp(r'\s+[a-zA-Zа-яА-Я]{1,2}$');
    if (trailingGarbage.hasMatch(cleanQuery)) {
      // Проверяем, не размер ли это (чтобы не удалить "размер L")
      final lastWord = cleanQuery.split(' ').last.toUpperCase();
      if (!['S', 'M', 'L', 'XL', 'XXL', 'XS'].contains(lastWord)) {
        cleanQuery = cleanQuery.replaceAll(trailingGarbage, '');
      }
    }

    // 5. Защита от пустого запроса
    if (cleanQuery.isEmpty || cleanQuery.length < 2) {
      cleanQuery = query.trim();
    }

    return {
      'cleanQuery': cleanQuery,
      'maxPrice': maxPrice,
    };
  }

  static SearchConfig generateWB(String query) {
    final parsed = parseQuery(query);
    final encoded = Uri.encodeComponent(parsed['cleanQuery']);
    final url = 'https://www.wildberries.ru/catalog/0/search.aspx?search=$encoded&sort=price_asc';
    
    final filters = ['Сортировка: по цене'];
    if (parsed['maxPrice'] != null) filters.add('Бюджет: до ${parsed['maxPrice'].toInt()} ₽');

    return SearchConfig(marketplace: 'Wildberries', filters: filters, deepLink: url);
  }

  static SearchConfig generateOzon(String query) {
    final parsed = parseQuery(query);
    final encoded = Uri.encodeComponent(parsed['cleanQuery']);
    String url = 'https://www.ozon.ru/search/?text=$encoded&sort=price_asc';
    
    final filters = ['Сортировка: по цене'];
    if (parsed['maxPrice'] != null) {
      url += '&price=0-${parsed['maxPrice'].toInt()}';
      filters.add('Цена: до ${parsed['maxPrice'].toInt()} ₽');
    }

    return SearchConfig(marketplace: 'Ozon', filters: filters, deepLink: url);
  }
}
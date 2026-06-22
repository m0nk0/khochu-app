import 'package:shared_preferences/shared_preferences.dart';

class TrafficTracker {
  static const String _keySearches = 'total_searches';
  static const String _keyClicksWb = 'total_clicks_wb';
  static const String _keyClicksOzon = 'total_clicks_ozon';
  static const String _keyEstimatedGmv = 'estimated_gmv_rub';

  // Считаем поисковые запросы
  static Future<void> trackSearch() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keySearches) ?? 0;
    await prefs.setInt(_keySearches, current + 1);
  }

  // Считаем клики по маркетплейсам и считаем потенциальный оборот
  static Future<void> trackClick(String marketplace, double productPrice) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (marketplace == 'wildberries') {
      int clicks = prefs.getInt(_keyClicksWb) ?? 0;
      await prefs.setInt(_keyClicksWb, clicks + 1);
    } else if (marketplace == 'ozon') {
      int clicks = prefs.getInt(_keyClicksOzon) ?? 0;
      await prefs.setInt(_keyClicksOzon, clicks + 1);
    }

    // Считаем потенциальный оборот (GMV)
    double gmv = prefs.getDouble(_keyEstimatedGmv) ?? 0.0;
    await prefs.setDouble(_keyEstimatedGmv, gmv + productPrice);
  }

    // Получаем статистику (для экрана настроек или отчета)
  static Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'searches': prefs.getInt(_keySearches) ?? 0,
      'clicks_wb': prefs.getInt(_keyClicksWb) ?? 0,
      'clicks_ozon': prefs.getInt(_keyClicksOzon) ?? 0,
      'total_clicks': (prefs.getInt(_keyClicksWb) ?? 0) + (prefs.getInt(_keyClicksOzon) ?? 0),
      'estimated_gmv': prefs.getDouble(_keyEstimatedGmv) ?? 0.0,
    };
  }

  // Сброс статистики (для тестов)
  static Future<void> resetStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySearches, 0);
    await prefs.setInt(_keyClicksWb, 0);
    await prefs.setInt(_keyClicksOzon, 0);
    await prefs.setDouble(_keyEstimatedGmv, 0.0);
  }
}
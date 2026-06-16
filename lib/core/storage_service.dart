import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../features/bookmarks/models/saved_item.dart';

class StorageService {
  static const String _historyKey = 'search_history';
  static const String _savedKey = 'saved_items';

  static Future<void> saveHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    history.remove(query);
    history.insert(0, query);
    if (history.length > 10) history = history.sublist(0, 10);
    await prefs.setStringList(_historyKey, history);
  }

  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
    }

  static Future<void> saveItem(SavedItem item) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> itemsJson = prefs.getStringList(_savedKey) ?? [];
    itemsJson.removeWhere((json) => json.contains('"id":"${item.id}"'));
    itemsJson.add(jsonEncode(item.toJson()));
    await prefs.setStringList(_savedKey, itemsJson);
  }

  static Future<List<SavedItem>> getSavedItems() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> itemsJson = prefs.getStringList(_savedKey) ?? [];
    return itemsJson.map((json) => SavedItem.fromJson(jsonDecode(json))).toList();
  }

  static Future<void> deleteItem(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> itemsJson = prefs.getStringList(_savedKey) ?? [];
    itemsJson.removeWhere((json) => json.contains('"id":"$id"'));
    await prefs.setStringList(_savedKey, itemsJson);
  }
}
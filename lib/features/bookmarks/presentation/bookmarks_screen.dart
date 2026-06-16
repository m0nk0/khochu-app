import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/storage_service.dart';
import '../models/saved_item.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<SavedItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await StorageService.getSavedItems();
    setState(() => _items = items);
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;

        if (_items.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFFFFF5F7),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                    child: const Icon(Icons.favorite_border, size: 64, color: Color(0xFFFF0050)),
                  ),
                  const SizedBox(height: 24),
                  const Text('Пока тут пусто 🥺', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Найди что-то классное и нажми 💖', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        final grouped = <String, List<SavedItem>>{};
        for (var item in _items) {
          grouped.putIfAbsent(item.collection, () => []).add(item);
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFFF5F7),
          appBar: AppBar(
            title: const Text('Мои хочушки 💖', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final collectionName = grouped.keys.elementAt(index);
              final collectionItems = grouped[collectionName]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(collectionName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFCB11AB))),
                  ),
                  isTablet 
                    ? GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.9),
                        itemCount: collectionItems.length,
                        itemBuilder: (context, i) => _buildItemCard(collectionItems[i]),
                      )
                    : Column(
                        children: collectionItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _buildItemCard(item),
                        )).toList(),
                      ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildItemCard(SavedItem item) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(item.marketplace == 'Wildberries' ? Icons.shopping_bag : Icons.shopping_cart, 
                     color: item.marketplace == 'Wildberries' ? const Color(0xFFCB11AB) : const Color(0xFF005BFF), size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.name, maxLines: 2, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00F2EA).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.targetPrice > 0 ? '💰 Цель: до ${item.targetPrice.toInt()} ₽' : 'Без целевой цены',
                style: const TextStyle(color: Color(0xFF008B8B), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openLink(item.url),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0050),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.visibility, size: 24),
                    label: const Text('Проверить цену', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 28, color: Colors.red),
                    onPressed: () async {
                      await StorageService.deleteItem(item.id);
                      _loadItems();
                    },
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
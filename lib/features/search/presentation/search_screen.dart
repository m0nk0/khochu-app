import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/storage_service.dart';
import '../../../features/bookmarks/models/saved_item.dart';
import '../models/search_config.dart';
import '../services/link_generator.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<String> _history = [];
  List<SearchConfig> _results = [];
  bool _isSearching = false;
  double? _extractedMaxPrice;

  // Быстрые фильтры-настроения
  final List<String> _moods = ['👗 На свидание', '🏖️ В отпуск', '💼 В офис', '🎁 Подарок', '🔥 Тренд'];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await StorageService.getHistory();
    setState(() => _history = history);
  }

  void _processQuery(String query) {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);

    Future.delayed(const Duration(milliseconds: 600), () async {
      await StorageService.saveHistory(query);
      await _loadHistory();

      final parsed = LinkGenerator.parseQuery(query);
      _extractedMaxPrice = parsed['maxPrice'];

      setState(() {
        _results = [
          LinkGenerator.generateWB(parsed['cleanQuery']),
          LinkGenerator.generateOzon(parsed['cleanQuery']),
        ];
        _isSearching = false;
      });
    });
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showSaveDialog(SearchConfig config) {
    final nameController = TextEditingController(text: _controller.text);
    final priceController = TextEditingController(text: _extractedMaxPrice?.toInt().toString() ?? '');
    String selectedCollection = 'Мои образы ✨';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Добавить в хочушки 💖', style: TextStyle(fontSize: 22)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Что это?', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Хочу купить до (₽)', prefixText: '💰 ', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCollection,
                decoration: const InputDecoration(labelText: 'Коллекция', border: OutlineInputBorder()),
                items: ['Мои образы ✨', 'Гардероб 2024 👗', 'Подарки 🎁', 'Дом и уют 🏡']
                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedCollection = val!),
              )
            ]),
          ),
          actions: [
            TextButton(onPressed: Navigator.of(context).pop, child: const Text('Отмена', style: TextStyle(fontSize: 18))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0050), foregroundColor: Colors.white),
              onPressed: () async {
                final item = SavedItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  marketplace: config.marketplace,
                  url: config.deepLink,
                  collection: selectedCollection,
                  targetPrice: double.tryParse(priceController.text) ?? 0,
                );
                await StorageService.saveItem(item);
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Добавлено в хочушки! 💖'), backgroundColor: Color(0xFF00F2EA), behavior: SnackBarBehavior.floating),
                  );
                }
              },
              child: const Text('Хочу!'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Адаптивность: если ширина > 600, это планшет
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;

        return Scaffold(
          backgroundColor: const Color(0xFFFFF5F7), // Нежный фон
          appBar: AppBar(
            title: const Text('Хочу! 💖', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Поле поиска (ОГРОМНОЕ)
                TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    hintText: 'Что ты хочешь сегодня? ✨',
                    hintStyle: const TextStyle(fontSize: 18, color: Colors.grey),
                    prefixIcon: const Icon(Icons.auto_awesome, size: 32, color: Color(0xFFFF0050)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded, size: 32, color: Colors.white),
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFFFF0050)),
                      onPressed: () => _processQuery(_controller.text),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  ),
                  onSubmitted: _processQuery,
                ),
                const SizedBox(height: 16),

                // Чипсы настроений
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _moods.map((mood) => ActionChip(
                    label: Text(mood, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFFF0050), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      _controller.text = mood;
                      _processQuery(mood);
                    },
                  )).toList(),
                ),
                const SizedBox(height: 24),

                // Рентген (Пузырь понимания)
                if (_results.isNotEmpty && !_isSearching) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF0050), Color(0xFFC06BFF)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: const Color(0xFFFF0050).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [Icon(Icons.lightbulb, color: Colors.white, size: 24), SizedBox(width: 8), Text('Я тебя поняла! ✨', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
                        const SizedBox(height: 8),
                        Text(
                          'Ищем: "${LinkGenerator.parseQuery(_controller.text)['cleanQuery']}"'
                          '${_extractedMaxPrice != null ? ' | Бюджет: до ${_extractedMaxPrice!.toInt()} ₽ 💸' : ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Результаты (Адаптивные!)
                Expanded(
                  child: _isSearching
                      ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          CircularProgressIndicator(color: Color(0xFFFF0050), strokeWidth: 4),
                          SizedBox(height: 16),
                          Text('Подбираю лучшие варианты... 💖', style: TextStyle(fontSize: 18, color: Colors.grey))
                        ]))
                      : isTablet 
                        ? GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.1),
                            itemCount: _results.length,
                            itemBuilder: (context, index) => _buildMarketplaceCard(_results[index]),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildMarketplaceCard(_results[index]),
                            ),
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarketplaceCard(SearchConfig config) {
    final isWb = config.marketplace == 'Wildberries';
    final color = isWb ? const Color(0xFFCB11AB) : const Color(0xFF005BFF); // Фирменные цвета

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: Icon(isWb ? Icons.shopping_bag : Icons.shopping_cart, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Text(config.marketplace, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: config.filters.map((f) => Chip(
              label: Text(f, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              backgroundColor: const Color(0xFFFFF5F7),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )).toList()),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openLink(config.deepLink),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 24),
                    label: const Text('Открыть', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                  child: IconButton(
                    icon: const Icon(Icons.favorite_border, size: 32, color: Color(0xFFFF0050)),
                    onPressed: () => _showSaveDialog(config),
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
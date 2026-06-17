import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:confetti/confetti.dart';
import '../../../core/storage_service.dart';
import '../../../features/bookmarks/models/saved_item.dart';
import '../models/search_config.dart';
import '../services/link_generator.dart';
import '../widgets/smart_mascot.dart'; // <-- Импортируем наш новый умный маскот

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  // Состояния маскота
  String _mascotMood = 'idle'; // idle, thinking, excited, sad
  bool _isMascotActive = false; // true = в центре, false = в углу

  List<String> _history = [];
  List<SearchConfig> _results = [];
  bool _isSearching = false;
  double? _extractedMaxPrice;

  final List<String> _moods = ['👗 На свидание', '🏖️ В отпуск', '💼 В офис', '🎁 Подарок', ' Тренд'];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await StorageService.getHistory();
    setState(() => _history = history);
  }

  // 🧠 Логика запуска поиска
  void _processQuery(String query) {
    if (query.trim().isEmpty) return;
    
    // 1. Маскот в центр, задумывается
    setState(() {
      _isSearching = true;
      _isMascotActive = true; 
      _mascotMood = 'thinking';
    });

    // Имитация поиска
    Future.delayed(const Duration(milliseconds: 1500), () async {
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
        
        // Если ничего не нашли
        if (_results.isEmpty) {
          _mascotMood = 'sad';
        } else {
          // Если нашли - возвращаем в угол, но довольный
          _isMascotActive = false; 
          _mascotMood = 'idle'; 
        }
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
                items: ['Мои образы ✨', 'Гардероб 2024 👗', 'Подарки 🎁', 'Дом и уют ']
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
                  _triggerCelebration();
                }
              },
              child: const Text('Хочу!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  //  Функция праздника
  void _triggerCelebration() {
    setState(() {
      _isMascotActive = true; // Летит в центр
      _mascotMood = 'excited';
    });
    _confettiController.play();

    // Через 3 секунды возвращается в угол
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isMascotActive = false;
          _mascotMood = 'idle';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;

        return Scaffold(
          backgroundColor: const Color(0xFFFFF5F7),
          appBar: AppBar(
            title: const Text('Хочу! 💖', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              // Если маскот в углу, его можно показать тут, но мы сделаем оверлей ниже
            ]
          ),
          body: Stack(
            children: [
              // 1. Основной контент
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    
                    // Пузырь понимания
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
                            const Row(children: [
                              Icon(Icons.lightbulb, color: Colors.white, size: 24),
                              SizedBox(width: 8),
                              Text('Я тебя поняла! ✨', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
                            ]),
                            const SizedBox(height: 8),
                            Text(
                              'Ищем: "${LinkGenerator.parseQuery(_controller.text)['cleanQuery']}"'
                              '${_extractedMaxPrice != null ? ' | Бюджет: до ${_extractedMaxPrice!.toInt()} ₽ ' : ''}',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                                      // Результаты
                    Expanded(
                      child: _isSearching
                          ? const SizedBox.shrink() // Пусто, маскот сам покажет "думаю"
                          : _results.isEmpty
                              ? const SizedBox.shrink() // Пусто, маскот сам стоит по центру
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

                              // 2. МАСКОТ (Анимированное перемещение)
                            // 2. МАСКОТ (Анимированное перемещение)
              AnimatedPositioned(
                duration: const Duration(seconds: 1),
                curve: Curves.elasticOut,
                
                // Если есть результаты и маскот в покое → в футер
                // Иначе → на весь экран (для центрирования)
                top: (_results.isNotEmpty && _mascotMood == 'idle') ? null : 0,
                bottom: (_results.isNotEmpty && _mascotMood == 'idle') ? 20 : 0,
                left: 0,
                right: 0,
                
                child: (_results.isNotEmpty && _mascotMood == 'idle')
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: SmartMascot(mood: _mascotMood, size: 120),
                      )
                    : Center(
                        child: (_results.isEmpty && _mascotMood == 'idle')
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SmartMascot(mood: _mascotMood, size: 150),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Привет! Я твой умный помощник! 💖',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFCB11AB),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Что ты хочешь найти сегодня?',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              )
                            : SmartMascot(mood: _mascotMood, size: 150),
                      ),
              ),

              // 3. Конфетти (поверх всего)
              Align(
                alignment: Alignment.topCenter,
                child: IgnorePointer( // Чтобы конфетти не мешали кликать
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [Color(0xFFFF0050), Color(0xFF00F2EA), Colors.yellow, Colors.purple],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarketplaceCard(SearchConfig config) {
    final isWb = config.marketplace == 'Wildberries';
    final color = isWb ? const Color(0xFFCB11AB) : const Color(0xFF005BFF);

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
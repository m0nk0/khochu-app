import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../../core/storage_service.dart';
import '../services/traffic_tracker.dart';
import '../services/parsers/ozon_parser.dart';
import '../../bookmarks/presentation/bookmarks_screen.dart';
import '../../bookmarks/models/saved_item.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../widgets/smart_mascot.dart';

class OzonSearchScreen extends StatefulWidget {
  const OzonSearchScreen({super.key});

  @override
  State<OzonSearchScreen> createState() => _OzonSearchScreenState();
}

class _OzonSearchScreenState extends State<OzonSearchScreen> {
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  final TextEditingController _searchController = TextEditingController();
  String _mascotMood = 'idle';

  List<Product> _products = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  String _currentQuery = '';
  int _currentPage = 1;
  bool _hasMorePages = true;
  bool _showLoadMoreButton = false;

  final List<String> _trends = [
    'Смартфоны',
    'Ноутбуки',
    'Кроссовки',
    'Платья',
    'Телевизоры',
    'Кофемашины',
    'Пылесосы',
    'Игрушки',
  ];

  @override
  void dispose() {
    _confettiController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) return;

    TrafficTracker.trackSearch();

    setState(() {
      _isSearching = true;
      _mascotMood = 'thinking';
      _products = [];
      _currentQuery = query;
      _currentPage = 1;
      _hasMorePages = true;
      _showLoadMoreButton = false;
    });

    try {
      debugPrint('🔵 Ozon поиск: "$query" (страница 1)');
      
      final parser = OzonParser();
      final products = await parser.search(query, page: 1);

      if (mounted) {
        setState(() {
          _products = products;
          _isSearching = false;
          _mascotMood = products.isEmpty ? 'sad' : 'excited';
          _hasMorePages = products.length >= 5;
        });

        if (products.isNotEmpty) {
          _triggerCelebration();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Найдено ${products.length} товаров на Ozon'),
              backgroundColor: const Color(0xFF005BFF),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Товары не найдены. Попробуйте другой запрос.'),
              backgroundColor: Color(0xFFFF6B35),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Ошибка поиска Ozon: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _mascotMood = 'sad';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка поиска: $e'),
            backgroundColor: const Color(0xFFFF0050),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMorePages || _currentQuery.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
      _showLoadMoreButton = false;
    });

    try {
      final nextPage = _currentPage + 1;
      debugPrint('📄 Загружаем страницу $nextPage...');
      
      final parser = OzonParser();
      final newProducts = await parser.search(_currentQuery, page: nextPage);

      if (mounted) {
        setState(() {
          _products.addAll(newProducts);
          _currentPage = nextPage;
          _isLoadingMore = false;
          _hasMorePages = newProducts.length >= 5;
          _mascotMood = 'excited';
        });

        if (newProducts.isNotEmpty) {
          _triggerCelebration();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Добавлено ${newProducts.length} товаров (всего: ${_products.length})'),
              backgroundColor: const Color(0xFF005BFF),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Больше товаров не найдено'),
              backgroundColor: Color(0xFFFF6B35),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки страницы: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      final reachedEnd = metrics.extentAfter <= 0;
      
      if (reachedEnd && _hasMorePages && !_isLoadingMore && _products.isNotEmpty) {
        if (!_showLoadMoreButton) {
          setState(() {
            _showLoadMoreButton = true;
          });
          debugPrint('👇 Пользователь доскроллил до конца — показываем кнопку');
        }
      }
    }
  }

  void _triggerCelebration() {
    _confettiController.play();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _mascotMood = 'idle';
        });
      }
    });
  }

  void _showSaveDialog(Product product) {
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(text: product.price.round().toString());
    String selectedCollection = 'Мои образы ✨';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Добавить в хочушки 💖', style: TextStyle(fontSize: 22)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Что это?', border: OutlineInputBorder())
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Хочу купить до (₽)', prefixText: ' ', border: OutlineInputBorder())
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCollection,
                decoration: const InputDecoration(labelText: 'Коллекция', border: OutlineInputBorder()),
                items: ['Мои образы ✨', 'Гардероб 2024 👗', 'Подарки 🎁', 'Дом и уют 🏠']
                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedCollection = val!),
              )
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена', style: TextStyle(fontSize: 18))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005BFF),
                foregroundColor: Colors.white
              ),
              onPressed: () async {
                final item = SavedItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  marketplace: product.marketplace,
                  url: product.deepLink,
                  collection: selectedCollection,
                  targetPrice: double.tryParse(priceController.text) ?? 0,
                );
                await StorageService.saveItem(item);
                if (mounted) {
                  Navigator.of(dialogContext).pop();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('🔵 Ozon', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF005BFF)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFF0F4FF),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Поиск по Ozon...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF005BFF)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Color(0xFF005BFF)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _products = [];
                                    _currentQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onSubmitted: (value) => _searchProducts(value),
                    ),
                    const SizedBox(height: 12),
                    
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _trends.map((trend) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(trend),
                            onPressed: () {
                              _searchController.text = trend;
                              _searchProducts(trend);
                            },
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(color: Color(0xFF005BFF)),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isSearching
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF005BFF)),
                            SizedBox(height: 16),
                            Text('Открываем Ozon и ищем товары...', style: TextStyle(color: Colors.grey)),
                            SizedBox(height: 8),
                            Text('Это займёт ~20 секунд', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      )
                    : _products.isNotEmpty
                        ? NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              _onScrollNotification(notification);
                              return false;
                            },
                            child: GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 600,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent: 360,
                              ),
                              itemCount: _products.length + 
                                  (_isLoadingMore ? 1 : 0) + 
                                  (_showLoadMoreButton ? 1 : 0) +
                                  (!_hasMorePages ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (_isLoadingMore && index == _products.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(color: Color(0xFF005BFF)),
                                    ),
                                  );
                                }
                                
                                if (_showLoadMoreButton && 
                                    index == _products.length + (_isLoadingMore ? 1 : 0)) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: ElevatedButton.icon(
                                        onPressed: _loadMoreProducts,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF005BFF),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                            horizontal: 32,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          elevation: 4,
                                        ),
                                        icon: const Icon(Icons.arrow_downward, size: 24),
                                        label: const Text(
                                          'Загрузить ещё',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                
                                if (!_hasMorePages && 
                                    index == _products.length + (_isLoadingMore ? 1 : 0) + (_showLoadMoreButton ? 1 : 0)) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Это все товары',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                
                                return ProductCard(
                                  product: _products[index],
                                  onAddToWishlist: () => _showSaveDialog(_products[index]),
                                );
                              },
                            ),
                          )
                        : _currentQuery.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SmartMascot(mood: _mascotMood, size: 100),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Введите запрос для поиска',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF005BFF),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Или нажмите на чипс выше',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SmartMascot(mood: _mascotMood, size: 100),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Ничего не найдено',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF005BFF),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Попробуйте другой запрос',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
              ),
            ],
          ),

          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [Color(0xFF005BFF), Color(0xFF003EBA), Colors.blue, Colors.cyan],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 80,
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 0) {
            Navigator.pop(context);
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookmarksScreen()),
            );
          }
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 32),
            selectedIcon: Icon(Icons.home, size: 32, color: Color(0xFF005BFF)),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border, size: 32),
            selectedIcon: Icon(Icons.favorite, size: 32, color: Color(0xFF005BFF)),
            label: 'Хочушки',
          ),
        ],
      ),
    );
  }
}
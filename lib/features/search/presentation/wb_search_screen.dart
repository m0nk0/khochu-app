import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../../core/storage_service.dart';
import '../../../core/cache/cache_manager.dart';
import '../services/traffic_tracker.dart';
import '../services/bhapi_service.dart';
import '../../bookmarks/presentation/bookmarks_screen.dart';
import '../../bookmarks/models/saved_item.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../widgets/smart_mascot.dart';

class WbSearchScreen extends StatefulWidget {
  const WbSearchScreen({super.key});

  @override
  State<WbSearchScreen> createState() => _WbSearchScreenState();
}

class _WbSearchScreenState extends State<WbSearchScreen> {
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  final TextEditingController _searchController = TextEditingController();
  String _mascotMood = 'idle';

  List<Product> _products = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _isLoadingImages = false;
  bool _isFromCache = false;  // 🆕 Флаг: данные из кэша
  String _currentQuery = '';
  int _currentPage = 1;
  bool _hasMorePages = true;
  bool _showLoadMoreButton = false;

  // Чипсы трендов
  final List<String> _trends = [
    'Платья',
    'Кроссовки',
    'Косметика',
    'Сумки',
    'Телефоны',
    'Игрушки',
    'Куртки',
    'Часы',
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 🆕 Загружаем товары из кэша при ошибке
  Future<List<Product>?> _loadFromCache(String query) async {
    try {
      final cacheKey = 'search:wb:$query:page1:limit20';
      final cached = await CacheManager().get(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('✅ Загружено из кэша: ${cached.length} товаров');
        return cached;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Не удалось загрузить из кэша: $e');
      return null;
    }
  }

  // Поиск товаров
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
      _isLoadingImages = false;
      _isFromCache = false;
    });

    try {
      debugPrint('🔍 WB поиск: "$query"');
      
      final products = await BhApiService.searchWbProducts(
        query,
        page: 1,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _products = products;
          _isSearching = false;
          _mascotMood = products.isEmpty ? 'sad' : 'excited';
          _hasMorePages = products.length >= 20;
        });

        if (products.isNotEmpty) {
          _triggerCelebration();
          _loadProductImages();
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
      debugPrint('❌ Ошибка поиска: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _mascotMood = 'sad';
        });
        
        // 🆕 Пытаемся загрузить из кэша
        final cachedProducts = await _loadFromCache(query);
        
        if (cachedProducts != null && cachedProducts.isNotEmpty) {
          // Показываем кэшированные данные
          setState(() {
            _products = cachedProducts;
            _mascotMood = 'idle';
            _isFromCache = true;
            _hasMorePages = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Сервис временно недоступен. Показаны сохранённые данные (${cachedProducts.length} шт.).'),
              backgroundColor: const Color(0xFFFF6B35),
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Загружаем картинки для кэшированных товаров
          _loadProductImages();
        } else {
          // Показываем ошибку с кнопкой "Повторить"
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Expanded(
                    child: Text('⚠️ Сервис WB временно недоступен'),
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      _searchProducts(query);
                    },
                    child: const Text(
                      'Повторить',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFFF0050),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  // Загрузить следующую страницу
  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMorePages) return;

    setState(() {
      _isLoadingMore = true;
      _showLoadMoreButton = false;
    });

    try {
      final nextPage = _currentPage + 1;
      debugPrint('📄 Загружаем страницу $nextPage...');
      
      final newProducts = await BhApiService.searchWbProducts(
        _currentQuery,
        page: nextPage,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _products.addAll(newProducts);
          _currentPage = nextPage;
          _isLoadingMore = false;
          _hasMorePages = newProducts.length >= 20;
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
          
          _loadProductImages();
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

  // 🆕 Загружаем картинки БАТЧАМИ (защита от 429)
  Future<void> _loadProductImages() async {
    if (_products.isEmpty || _isLoadingImages) return;

    final productsWithoutImages = _products
        .where((p) => p.imageUrl.isEmpty && p.deepLink.isNotEmpty)
        .toList();

    if (productsWithoutImages.isEmpty) {
      debugPrint('🖼️ Все картинки уже загружены');
      return;
    }

    setState(() {
      _isLoadingImages = true;
    });

    debugPrint('🖼️ Загружаем картинки для ${productsWithoutImages.length} товаров батчами по 8...');

    const int batchSize = 8;
    const Duration batchDelay = Duration(seconds: 2);

    for (var i = 0; i < productsWithoutImages.length; i += batchSize) {
      final end = (i + batchSize < productsWithoutImages.length) 
          ? i + batchSize 
          : productsWithoutImages.length;
      final batch = productsWithoutImages.sublist(i, end);
      
      debugPrint('📦 Батч ${i ~/ batchSize + 1}: загружаем ${batch.length} товаров...');

      final futures = batch.map((product) async {
        try {
          final details = await BhApiService.getWbProductDetails(product.deepLink);
          if (details != null && details.imageUrl.isNotEmpty) {
            return product.copyWith(imageUrl: details.imageUrl);
          }
        } catch (e) {
          debugPrint('⚠️ Ошибка для ${product.id}: $e');
        }
        return product;
      }).toList();

      final updatedBatch = await Future.wait(futures);

      if (mounted) {
        setState(() {
          for (var updated in updatedBatch) {
            if (updated.imageUrl.isNotEmpty) {
              final index = _products.indexWhere((p) => p.id == updated.id);
              if (index != -1) {
                _products[index] = updated;
              }
            }
          }
        });
      }

      if (i + batchSize < productsWithoutImages.length) {
        debugPrint('⏸️ Пауза 2 секунды перед следующим батчем...');
        await Future.delayed(batchDelay);
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingImages = false;
      });
      
      final loadedCount = _products.where((p) => p.imageUrl.isNotEmpty).length;
      debugPrint('✅ Загружено картинок: $loadedCount из ${_products.length}');
    }
  }

  // Обработчик скролла
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
                backgroundColor: const Color(0xFFFF0050),
                foregroundColor: Colors.white
              ),
              onPressed: () async {
                final item = SavedItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  marketplace: product.marketplace,
                  url: product.openLink,
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
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: const Text('🟣 Wildberries', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFCB11AB)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Строка поиска
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFFFF5F7),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Поиск по WB...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFCB11AB)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Color(0xFFCB11AB)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _products = [];
                                    _currentQuery = '';
                                    _isFromCache = false;
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
                    
                    // Чипсы трендов
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
                              side: const BorderSide(color: Color(0xFFCB11AB)),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // 🆕 Баннер "Данные из кэша"
              if (_isFromCache)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFFFFF3CD),
                  child: Row(
                    children: [
                      const Icon(Icons.cached, color: Color(0xFFFF6B35), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Показаны сохранённые данные (сервис временно недоступен)',
                          style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _searchProducts(_currentQuery),
                        child: const Text(
                          'Обновить',
                          style: TextStyle(fontSize: 12, color: Color(0xFFCB11AB)),
                        ),
                      ),
                    ],
                  ),
                ),

              // Индикатор загрузки картинок
              if (_isLoadingImages)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Color(0xFFCB11AB),
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Загружаем картинки...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

              // Контент
              Expanded(
                child: _isSearching
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFCB11AB)),
                            SizedBox(height: 16),
                            Text('Ищем товары на WB...', style: TextStyle(color: Colors.grey)),
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
                                      child: CircularProgressIndicator(color: Color(0xFFCB11AB)),
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
                                          backgroundColor: const Color(0xFFCB11AB),
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
                                          'Показать ещё 20',
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
                                        color: Color(0xFFCB11AB),
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
                                        color: Color(0xFFCB11AB),
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

          // Конфетти
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [Color(0xFFCB11AB), Color(0xFF9B0B8B), Colors.purple, Colors.pink],
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
            selectedIcon: Icon(Icons.home, size: 32, color: Color(0xFFCB11AB)),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border, size: 32),
            selectedIcon: Icon(Icons.favorite, size: 32, color: Color(0xFFCB11AB)),
            label: 'Хочушки',
          ),
        ],
      ),
    );
  }
}
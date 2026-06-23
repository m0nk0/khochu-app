import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../../core/storage_service.dart';
import '../services/traffic_tracker.dart';
import '../services/bhapi_service.dart';
import '../services/parsers/ozon_parser.dart';
import '../../bookmarks/presentation/bookmarks_screen.dart';
import '../../bookmarks/models/saved_item.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../widgets/smart_mascot.dart';

class SearchEverywhereScreen extends StatefulWidget {
  const SearchEverywhereScreen({super.key});

  @override
  State<SearchEverywhereScreen> createState() => _SearchEverywhereScreenState();
}

class _SearchEverywhereScreenState extends State<SearchEverywhereScreen> {
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

  // Статусы загрузки
  bool _isWbLoading = false;
  bool _isOzonLoading = false;
  int _wbCount = 0;
  int _ozonCount = 0;

  // 🆕 Фильтр по маркетплейсу
  String _marketplaceFilter = 'all';  // all | wildberries | ozon

  // Сортировка
  String _sortBy = 'популярности';

  final List<String> _trends = [
    'Платья',
    'Кроссовки',
    'Смартфоны',
    'Косметика',
    'Ноутбуки',
    'Сумки',
    'Телевизоры',
    'Игрушки',
  ];

  @override
  void dispose() {
    _confettiController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 🔍 ГЛАВНЫЙ ПОИСК: параллельно WB + Ozon
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
      _isWbLoading = true;
      _isOzonLoading = true;
      _wbCount = 0;
      _ozonCount = 0;
    });

    // Параллельные запросы
    final wbFuture = _searchWb(query, page: 1);
    final ozonFuture = _searchOzon(query, page: 1);

    await Future.wait([wbFuture, ozonFuture]);

    if (mounted) {
      setState(() {
        _isSearching = false;
        _mascotMood = _products.isEmpty ? 'sad' : 'excited';
        _hasMorePages = _products.length >= 10;
      });

      if (_products.isNotEmpty) {
        _sortProducts();
        _triggerCelebration();
      }
    }
  }

  // 🟣 WB: показываем СРАЗУ, картинки в фоне
  Future<void> _searchWb(String query, {int page = 1}) async {
    try {
      debugPrint('🟣 WB поиск: "$query" (страница $page)');
      final products = await BhApiService.searchWbProducts(query, page: page, limit: 20);

      // 🆕 Показываем карточки СРАЗУ (без картинок, с shimmer)
      if (mounted) {
        setState(() {
          _products.addAll(products);
          _wbCount += products.length;
          _isWbLoading = false;
        });
      }

      // 🆕 Картинки грузим в фоне (не блокируем UI)
      _loadWbImagesInBackground(products);
    } catch (e) {
      debugPrint('❌ WB ошибка: $e');
      if (mounted) setState(() => _isWbLoading = false);
    }
  }

  // 🆕 Фоновая загрузка картинок WB батчами
  void _loadWbImagesInBackground(List<Product> products) async {
    const int batchSize = 8;
    const Duration batchDelay = Duration(seconds: 2);

    for (var i = 0; i < products.length; i += batchSize) {
      final end = (i + batchSize < products.length) ? i + batchSize : products.length;
      final batch = products.sublist(i, end);

      final updatedMap = <String, String>{};
      await Future.wait(batch.map((product) async {
        try {
          final details = await BhApiService.getWbProductDetails(product.deepLink);
          if (details != null && details.imageUrl.isNotEmpty) {
            updatedMap[product.id] = details.imageUrl;
          }
        } catch (e) {}
      }));

      // Обновляем UI батчами
      if (updatedMap.isNotEmpty && mounted) {
        setState(() {
          for (var i = 0; i < _products.length; i++) {
            if (updatedMap.containsKey(_products[i].id)) {
              _products[i] = _products[i].copyWith(imageUrl: updatedMap[_products[i].id]!);
            }
          }
        });
      }

      if (i + batchSize < products.length) await Future.delayed(batchDelay);
    }
  }

  // 🔵 Ozon
  Future<void> _searchOzon(String query, {int page = 1}) async {
    try {
      debugPrint('🔵 Ozon поиск: "$query" (страница $page)');
      final parser = OzonParser();
      final products = await parser.search(query, page: page);

      if (mounted) {
        setState(() {
          _products.addAll(products);
          _ozonCount += products.length;
          _isOzonLoading = false;
        });
        debugPrint('🔵 Ozon найдено: ${products.length}');
      }
    } catch (e) {
      debugPrint('❌ Ozon ошибка: $e');
      if (mounted) setState(() => _isOzonLoading = false);
    }
  }

  // 🆕 Сортировка
  void _sortProducts() {
    setState(() {
      switch (_sortBy) {
        case 'цене':
          _products.sort((a, b) => a.price.compareTo(b.price));
          break;
        case 'рейтингу':
          _products.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case 'продажам':
          _products.sort((a, b) => b.salesCount.compareTo(a.salesCount));
          break;
      }
    });
  }

  // 📄 Загрузить ещё
  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMorePages || _currentQuery.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
      _showLoadMoreButton = false;
    });

    final nextPage = _currentPage + 1;
    final wbFuture = _searchWb(_currentQuery, page: nextPage);
    final ozonFuture = _searchOzon(_currentQuery, page: nextPage);

    await Future.wait([wbFuture, ozonFuture]);

    if (mounted) {
      setState(() {
        _currentPage = nextPage;
        _isLoadingMore = false;
        _hasMorePages = _wbCount > 0 || _ozonCount > 0;
        _mascotMood = 'excited';
      });

      _sortProducts();
      _triggerCelebration();
    }
  }

  void _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      final reachedEnd = metrics.extentAfter <= 0;
      
      if (reachedEnd && _hasMorePages && !_isLoadingMore && _products.isNotEmpty) {
        if (!_showLoadMoreButton) {
          setState(() => _showLoadMoreButton = true);
        }
      }
    }
  }

  void _triggerCelebration() {
    _confettiController.play();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _mascotMood = 'idle');
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

  // 🆕 Фильтрованные товары
  List<Product> get _filteredProducts {
    if (_marketplaceFilter == 'all') return _products;
    return _products.where((p) => p.marketplace == _marketplaceFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('🔍 Поиск везде', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
              // Строка поиска
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFF0F4FF),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Ищем на WB и Ozon одновременно...',
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

              // 🆕 Индикаторы загрузки маркетплейсов
              if (_isWbLoading || _isOzonLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      _buildMarketplaceStatus(
                        icon: '🟣',
                        name: 'WB',
                        isLoading: _isWbLoading,
                        count: _wbCount,
                        color: const Color(0xFFCB11AB),
                      ),
                      const SizedBox(width: 16),
                      _buildMarketplaceStatus(
                        icon: '🔵',
                        name: 'Ozon',
                        isLoading: _isOzonLoading,
                        count: _ozonCount,
                        color: const Color(0xFF005BFF),
                      ),
                      const Spacer(),
                      if (_products.isNotEmpty)
                        Text(
                          'Всего: ${_products.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF005BFF),
                          ),
                        ),
                    ],
                  ),
                ),

              // 🆕 Фильтры + сортировка
              if (_products.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFFF0F4FF),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Фильтры по маркетплейсам
                        _buildFilterChip('Все', _marketplaceFilter == 'all', () {
                          setState(() => _marketplaceFilter = 'all');
                        }),
                        _buildFilterChip('🟣 WB (${_wbCount})', _marketplaceFilter == 'wildberries', () {
                          setState(() => _marketplaceFilter = 'wildberries');
                        }),
                        _buildFilterChip('🔵 Ozon (${_ozonCount})', _marketplaceFilter == 'ozon', () {
                          setState(() => _marketplaceFilter = 'ozon');
                        }),
                        const SizedBox(width: 16),
                        // Сортировка
                        ...['популярности', 'цене', 'рейтингу'].map((sort) {
                          final isSelected = _sortBy == sort;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(sort),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _sortBy = sort);
                                  _sortProducts();
                                }
                              },
                              selectedColor: const Color(0xFF005BFF),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white : const Color(0xFF005BFF),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Color(0xFF005BFF)),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              // Контент
              Expanded(
                child: _isSearching && _products.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF005BFF)),
                            SizedBox(height: 16),
                            Text('Ищем на WB и Ozon...', style: TextStyle(color: Colors.grey)),
                            SizedBox(height: 8),
                            Text('Это займёт ~15-30 секунд', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      )
                    : filteredProducts.isNotEmpty
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
                              itemCount: filteredProducts.length + 
                                  (_isLoadingMore ? 1 : 0) + 
                                  (_showLoadMoreButton ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (_isLoadingMore && index == filteredProducts.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(color: Color(0xFF005BFF)),
                                    ),
                                  );
                                }
                                
                                if (_showLoadMoreButton && 
                                    index == filteredProducts.length + (_isLoadingMore ? 1 : 0)) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: ElevatedButton.icon(
                                        onPressed: _loadMoreProducts,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF005BFF),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                          elevation: 4,
                                        ),
                                        icon: const Icon(Icons.arrow_downward, size: 24),
                                        label: const Text('Загрузить ещё', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  );
                                }
                                
                                return ProductCard(
                                  product: filteredProducts[index],
                                  onAddToWishlist: () => _showSaveDialog(filteredProducts[index]),
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
                                      'Ищем сразу на WB и Ozon!',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF005BFF)),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Введите запрос и нажмите Enter',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFCB11AB).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text('🟣 Wildberries', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCB11AB))),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF005BFF).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text('🔵 Ozon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF005BFF))),
                                        ),
                                      ],
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
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF005BFF)),
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
                colors: const [Color(0xFFCB11AB), Color(0xFF005BFF), Colors.purple, Colors.blue],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 80,
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 0) Navigator.pop(context);
          else if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarksScreen()));
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

  Widget _buildMarketplaceStatus({
    required String icon,
    required String name,
    required bool isLoading,
    required int count,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 4),
        if (isLoading)
          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF005BFF)))
        else
          Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF005BFF),
        labelStyle: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : const Color(0xFF005BFF),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF005BFF)),
        ),
      ),
    );
  }
}
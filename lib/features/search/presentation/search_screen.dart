import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../../core/storage_service.dart';
import '../services/traffic_tracker.dart';
import '../services/takprodam_api.dart';
import '../../bookmarks/presentation/bookmarks_screen.dart';
import '../../bookmarks/models/saved_item.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../widgets/smart_mascot.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  String _mascotMood = 'idle';

  List<Product> _products = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  dynamic _selectedCategoryId = null;
  String _selectedCategoryName = '🔥 Все товары';
  
  // Пагинация
  int _currentPage = 1;
  static const int _itemsPerPage = 30;
  static const int _maxPages = 3;
  bool _hasMorePages = true;
  
  // 🆕 Флаг: показывать ли кнопку "Показать ещё"
  // Появляется только когда пользователь доскроллил до конца
  bool _showLoadMoreButton = false;

  // Список категорий (без акций — они на главном экране)
  final List<Map<String, dynamic>> _categories = [
  {'id': null, 'title': '🔥 Все', 'emoji': '🔥'},
  {'id': 1, 'title': '👗 Одежда', 'emoji': '👗'},
  {'id': 8, 'title': '💄 Красота', 'emoji': '💄'},
  {'id': 9, 'title': '🧸 Детские', 'emoji': '🧸'},
  {'id': 7, 'title': '🏠 Техника', 'emoji': '🏠'},
  {'id': 6, 'title': '🌿 Дом', 'emoji': '🌿'},
  {'id': 4, 'title': '🚗 Авто', 'emoji': '🚗'},
  {'id': 18, 'title': '🍎 Продукты', 'emoji': '🍎'},
  {'id': 12, 'title': '💍 Украшения', 'emoji': '💍'},
  {'id': 17, 'title': '📱 Электроника', 'emoji': '📱'},
  {'id': 13, 'title': '🏃 Спорт', 'emoji': '🏃'},
  {'id': 11, 'title': '🎒 Аксессуары', 'emoji': '🎒'},
  {'id': 3, 'title': '🐾 Зоотовары', 'emoji': '🐾'},
];

  @override
  void initState() {
    super.initState();

    _loadProductsByCategory(null, '🔥 Все товары');
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // Загрузка товаров (первая страница или смена категории)
  Future<void> _loadProductsByCategory(dynamic categoryId, String categoryName) async {
    TrafficTracker.trackSearch();

    setState(() {
      _isSearching = true;
      _mascotMood = 'thinking';
      _selectedCategoryId = categoryId;
      _selectedCategoryName = categoryName;
      _products = [];
      _currentPage = 1;
      _hasMorePages = true;
      _showLoadMoreButton = false; // 🆕 Сбрасываем флаг кнопки
    });

    try {
      final products = await TakprodamApi.getProducts(
        categoryId: categoryId,
        limit: _itemsPerPage,
        page: 1,
      );

      if (mounted) {
        setState(() {
          _products = products;
          _isSearching = false;
          _mascotMood = products.isEmpty ? 'sad' : 'excited';
          _hasMorePages = products.length >= _itemsPerPage;
        });

        if (products.isNotEmpty) {
          _triggerCelebration();
        }
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки товаров: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _mascotMood = 'sad';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: $e'),
            backgroundColor: const Color(0xFFFF0050),
          ),
        );
      }
    }
  }

  // Загрузка следующей страницы
  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMorePages) return;
    if (_currentPage >= _maxPages) {
      debugPrint('⏹️ Достигнут лимит страниц ($_maxPages)');
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _showLoadMoreButton = false; // Скрываем кнопку во время загрузки
    });

    try {
      final nextPage = _currentPage + 1;
      debugPrint('📄 Загружаем страницу $nextPage...');
      
      final newProducts = await TakprodamApi.getProducts(
        categoryId: _selectedCategoryId,
        limit: _itemsPerPage,
        page: nextPage,
      );

      if (mounted) {
        setState(() {
          _products.addAll(newProducts);
          _currentPage = nextPage;
          _isLoadingMore = false;
          _hasMorePages = newProducts.length >= _itemsPerPage && nextPage < _maxPages;
          _mascotMood = 'excited';
          // Кнопка появится снова, когда пользователь доскроллит до конца
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
        }
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки страницы: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: $e'),
            backgroundColor: const Color(0xFFFF0050),
          ),
        );
      }
    }
  }

  // 🆕 Обработчик скролла — показываем кнопку при достижении конца
  void _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      // extentAfter == 0 означает, что пользователь доскроллил до конца
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
        title: const Text('Топ товаров 🏆', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
          Row(
            children: [
              // ========== ЛЕВАЯ КОЛОНКА: КАТЕГОРИИ ==========
              Container(
                width: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategoryId == category['id'];
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (!isSelected) {
                              _loadProductsByCategory(category['id'], category['title']);
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFFFF0050), Color(0xFFCB11AB)],
                                    )
                                  : null,
                              color: isSelected ? null : Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  category['emoji'],
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  category['title'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ========== ПРАВАЯ КОЛОНКА: ТОВАРЫ ==========
              Expanded(
                child: Column(
                  children: [
                    // Заголовок текущей категории
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: const Color(0xFFFFF5F7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCategoryName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFCB11AB),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isSearching
                                ? 'Загружаем товары...'
                                : 'Найдено: ${_products.length} товаров (стр. $_currentPage из $_maxPages)',
                            style: TextStyle(
                              fontSize: 13,
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
                                  CircularProgressIndicator(color: Color(0xFFFF0050)),
                                  SizedBox(height: 16),
                                  Text('Ищем лучшие товары...', style: TextStyle(color: Colors.grey)),
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
                              maxCrossAxisExtent: 600,   // Макс ширина карточки
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 360,       // ← ФИКСИРОВАННАЯ ВЫСОТА
                            ),
                                    // 🆕 Добавляем место для кнопки и индикатора загрузки
                                    itemCount: _products.length + 
                                        (_isLoadingMore ? 1 : 0) + 
                                        (_showLoadMoreButton ? 1 : 0) +
                                        (!_hasMorePages ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      // Индикатор загрузки
                                      if (_isLoadingMore && index == _products.length) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: CircularProgressIndicator(color: Color(0xFFFF0050)),
                                          ),
                                        );
                                      }
                                      
                                      // Кнопка "Показать ещё" (только если доскроллили)
                                      if (_showLoadMoreButton && 
                                          index == _products.length + (_isLoadingMore ? 1 : 0)) {
                                        return Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: ElevatedButton.icon(
                                              onPressed: _loadMoreProducts,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFFF0050),
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
                                                'Показать ещё 30',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      
                                      // Сообщение "Это все товары"
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
                                                  _currentPage >= _maxPages
                                                      ? 'Это все товары в категории'
                                                      : 'Больше нет товаров',
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
                                      
                                      // Обычная карточка товара
                                      return ProductCard(
                                        product: _products[index],
                                        onAddToWishlist: () => _showSaveDialog(_products[index]),
                                      );
                                    },
                                  ),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SmartMascot(mood: _mascotMood, size: 100),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Нет товаров в этой категории',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFCB11AB),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Попробуй другую категорию слева',
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
                colors: const [Color(0xFFFF0050), Color(0xFF00F2EA), Colors.yellow, Colors.purple],
              ),
            ),
          ),
        ],
      ),
      // 🆕 ФУТЕР КАК НА ГЛАВНОЙ
      bottomNavigationBar: NavigationBar(
        height: 80,
        selectedIndex: 0, // Всегда подсвечена "Главная"
        onDestinationSelected: (index) {
          if (index == 0) {
            // Возврат на главную
            Navigator.pop(context);
          } else if (index == 1) {
            // Переход в Хочушки
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
            selectedIcon: Icon(Icons.home, size: 32, color: Color(0xFFFF0050)),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border, size: 32),
            selectedIcon: Icon(Icons.favorite, size: 32, color: Color(0xFFFF0050)),
            label: 'Хочушки',
          ),
        ],
      ),
    );
  }
}
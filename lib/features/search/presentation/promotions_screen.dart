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

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  String _mascotMood = 'idle';

  List<Product> _products = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  int _loadedPromos = 0;
  int _totalPromos = 0;
  List<Map<String, dynamic>> _allPromotions = [];

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // Загружаем список акций
  Future<void> _loadPromotions() async {
    TrafficTracker.trackSearch();

    setState(() {
      _isSearching = true;
      _mascotMood = 'thinking';
      _products = [];
      _loadedPromos = 0;
      _totalPromos = 0;
    });

    try {
      debugPrint('💎 Загружаем акции...');
      
      final promotions = await TakprodamApi.getPromotions(limit: 15);
      
      if (promotions.isNotEmpty) {
        setState(() {
          _allPromotions = promotions;
          _totalPromos = promotions.length;
        });
        
        debugPrint('✅ Найдено ${promotions.length} акций. Собираем товары...');
        
        // Собираем товары из первых 5 акций сразу (быстрый старт)
        final initialProducts = <Product>[];
        final seenIds = <String>{};
        
        for (var i = 0; i < promotions.length && i < 5; i++) {
          final promo = promotions[i];
          final promoId = promo['id'] as int?;
          final promoTitle = promo['title'] ?? 'Акция';
          
          if (promoId != null) {
            if (i > 0) {
              await Future.delayed(const Duration(milliseconds: 500));
            }
            
            final promoProducts = await TakprodamApi.getPromotionProducts(
              promotionId: promoId,
              limit: 30,
            );
            
            debugPrint(' Акция "$promoTitle": ${promoProducts.length} товаров');
            
            for (var product in promoProducts) {
              if (!seenIds.contains(product.id)) {
                seenIds.add(product.id);
                initialProducts.add(product);
              }
            }
          }
          
          setState(() {
            _loadedPromos = i + 1;
          });
        }
        
        if (mounted) {
          setState(() {
            _products = initialProducts;
            _isSearching = false;
            _mascotMood = initialProducts.isEmpty ? 'sad' : 'excited';
          });
          
          if (initialProducts.isNotEmpty) {
            _triggerCelebration();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки акций: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _mascotMood = 'sad';
        });
      }
    }
  }

  // Загружаем ещё акции (следующие 5)
  Future<void> _loadMorePromotions() async {
    if (_isLoadingMore || _loadedPromos >= _allPromotions.length) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final seenIds = _products.map((p) => p.id).toSet();
      final startIdx = _loadedPromos;
      final endIdx = (startIdx + 5).clamp(0, _allPromotions.length);
      
      for (var i = startIdx; i < endIdx; i++) {
        final promo = _allPromotions[i];
        final promoId = promo['id'] as int?;
        final promoTitle = promo['title'] ?? 'Акция';
        
        if (promoId != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          
          final promoProducts = await TakprodamApi.getPromotionProducts(
            promotionId: promoId,
            limit: 30,
          );
          
          debugPrint('📦 Акция "$promoTitle": ${promoProducts.length} товаров');
          
          for (var product in promoProducts) {
            if (!seenIds.contains(product.id)) {
              seenIds.add(product.id);
              _products.add(product);
            }
          }
        }
        
        setState(() {
          _loadedPromos = i + 1;
        });
      }
      
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _mascotMood = 'excited';
        });
        
        _triggerCelebration();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Загружено акций: $_loadedPromos из $_totalPromos. Товаров: ${_products.length}'),
            backgroundColor: const Color(0xFF005BFF),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
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
                items: ['Мои образы ✨', 'Гардероб 2024 ', 'Подарки 🎁', 'Дом и уют 🏠']
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
        title: const Text('🔥 Горящие акции', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
              // Заголовок
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFFFF5F7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔥 Скидки до 90%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFCB11AB),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSearching
                          ? 'Загружаем акции...'
                          : 'Товаров: ${_products.length} | Акции: $_loadedPromos/$_totalPromos',
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
                child: _isSearching && _products.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFFF0050)),
                            SizedBox(height: 16),
                            Text('Ищем лучшие акции...', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : _products.isNotEmpty
                        ? NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              // Показываем кнопку "Загрузить ещё" при скролле до конца
                              if (notification is ScrollEndNotification) {
                                final reachedEnd = notification.metrics.extentAfter <= 0;
                                if (reachedEnd && _loadedPromos < _allPromotions.length && !_isLoadingMore) {
                                  // Автозагрузка следующей порции
                                  _loadMorePromotions();
                                }
                              }
                              return false;
                            },
                            child: GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.65,
                              ),
                              itemCount: _products.length + (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _products.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(color: Color(0xFFFF0050)),
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
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SmartMascot(mood: _mascotMood, size: 100),
                                const SizedBox(height: 16),
                                const Text(
                                  'Пока нет горящих акций',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFCB11AB),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Загляни позже — скидки обновляются каждый день!',
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
                colors: const [Color(0xFFFF0050), Color(0xFF00F2EA), Colors.yellow, Colors.purple, Colors.orange],
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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';
import '../services/traffic_tracker.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAddToWishlist;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAddToWishlist,
  });

  Future<void> _openProduct() async {
    final url = product.openLink;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      TrafficTracker.trackClick(product.marketplace, product.price);
    } catch (e) {
      debugPrint('❌ Не удалось открыть ссылку: $e');
    }
  }

  Widget _buildPlaceholder() {
    final List<Color> gradientColors;
    final IconData icon;
    final String label;

    switch (product.marketplace) {
      case 'wildberries':
        gradientColors = [const Color(0xFFCB11AB), const Color(0xFF9B0B8B)];
        icon = Icons.shopping_bag;
        label = 'Wildberries';
        break;
      case 'ozon':
        gradientColors = [const Color(0xFF005BFF), const Color(0xFF003EBA)];
        icon = Icons.local_mall;
        label = 'Ozon';
        break;
      case 'aliexpress':
        gradientColors = [const Color(0xFFFF4747), const Color(0xFFCC0000)];
        icon = Icons.store;
        label = 'AliExpress';
        break;
      default:
        gradientColors = [const Color(0xFFFF0050), const Color(0xFFCB11AB)];
        icon = Icons.card_giftcard;
        label = 'Хочу! 💖';
    }

    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.white.withOpacity(0.9)),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ========== КАРТИНКА (ПРИЖАТА К ВЕРХУ) ==========
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 160,
                            color: Colors.grey[100],
                            child: const Center(
                              child: CircularProgressIndicator(color: Color(0xFFFF0050)),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),

                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                      ],
                    ),
                    child: Text(
                      '${product.marketplaceIcon} ${product.marketplaceName}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                if (kDebugMode && product.commission != null && product.commission! > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_money, size: 10, color: Colors.white),
                          const SizedBox(width: 2),
                          Text(
                            '+${product.commission!.toStringAsFixed(0)}₽',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (product.discount != null && product.discount! > 0)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0050),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '-${product.discount!.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ========== КОНТЕНТ: FLEX С РАВНОМЕРНЫМ РАСПРЕДЕЛЕНИЕМ ==========
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // 🟢 РАВНОМЕРНОЕ РАСПРЕДЕЛЕНИЕ МЕЖДУ ЭЛЕМЕНТАМИ
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Название
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                      height: 1.2,
                    ),
                  ),

                  // Цена
                  Text(
                    product.price > 0 ? product.formattedPrice : 'Цена',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF0050),
                    ),
                  ),

                  // Кнопки (прижаты к низу благодаря spaceBetween)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _openProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF0050),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Открыть',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: onAddToWishlist,
                        icon: const Icon(Icons.favorite_border, color: Color(0xFFFF0050), size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.all(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
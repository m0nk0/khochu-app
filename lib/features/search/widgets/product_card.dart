import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
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

  // 🆕 ИНФОРМАТИВНЫЙ ПЛЕЙСХОЛДЕР С ЯРКИМ SHIMMER
  Widget _buildPlaceholder() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFB895C7),        // тёмный фиолетовый
      highlightColor: const Color(0xFFF0C8E8),   // яркий розовый
      period: const Duration(milliseconds: 1200),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFCB11AB).withOpacity(0.45),
              const Color(0xFF9B0B8B).withOpacity(0.65),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Информативный контент поверх shimmer
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Иконка маркетплейса
                  Row(
                    children: [
                      Text(
                        product.marketplaceIcon,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        product.marketplaceName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 3, color: Colors.black38, offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Название товара
                  Text(
                    product.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                      shadows: [
                        Shadow(blurRadius: 3, color: Colors.black38, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Цена
                  Text(
                    product.price > 0 ? product.formattedPrice : 'Цена уточняется',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Рейтинг и продажи
                  if (product.rating > 0 || product.salesCount > 0)
                    Row(
                      children: [
                        if (product.rating > 0) ...[
                          const Icon(Icons.star, size: 15, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(blurRadius: 2, color: Colors.black38, offset: Offset(0, 1)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (product.salesCount > 0)
                          Text(
                            product.formattedSales,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              shadows: [
                                Shadow(blurRadius: 2, color: Colors.black38, offset: Offset(0, 1)),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),

            // Индикатор загрузки в углу
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFFCB11AB),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'фото...',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFCB11AB),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          // ========== КАРТИНКА ИЛИ ПЛЕЙСХОЛДЕР ==========
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                // Если есть URL — грузим картинку, иначе — информативный плейсхолдер
                product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          // Пока грузится — показываем плейсхолдер
                          return _buildPlaceholder();
                        },
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),

                // Метка маркетплейса (только если есть картинка)
                if (product.imageUrl.isNotEmpty)
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

                // Бейдж комиссии (только в debug)
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

                // Бейдж скидки
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

          // ========== КОНТЕНТ С FLEX-РАСПРЕДЕЛЕНИЕМ ==========
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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

                  // Кнопки
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
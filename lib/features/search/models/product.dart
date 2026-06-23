class Product {
  final String id;
  final String name;
  final double price;
  final double? oldPrice;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final int salesCount;
  final String deepLink;
  final String marketplace;
  final DateTime cachedAt;
  final String extractionMethod;
  
  // НОВЫЕ ПОЛЯ ДЛЯ CPA (Такпродам)
  final String? trackingLink; // CPA-ссылка
  final double? commission; // Комиссия в рублях

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.oldPrice,
    required this.imageUrl,
    this.rating = 0,
    this.reviewCount = 0,
    this.salesCount = 0,
    required this.deepLink,
    required this.marketplace,
    required this.cachedAt,
    this.extractionMethod = 'selector',
    this.trackingLink,
    this.commission,
  });

  double? get discount {
    if (oldPrice == null || oldPrice == 0) return null;
    return ((oldPrice! - price) / oldPrice! * 100).roundToDouble();
  }

  String get formattedPrice {
    return '${price.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    )} ₽';
  }

  String get formattedCommission {
    if (commission == null || commission == 0) return '';
    return '+${commission!.toStringAsFixed(0)} ₽ комиссия';
  }

  String get formattedSales {
    if (salesCount == 0) return '';
    if (salesCount >= 1000) {
      return '${(salesCount / 1000).toStringAsFixed(1)}K купили';
    }
    return '$salesCount купили';
  }

  String get marketplaceIcon {
    switch (marketplace) {
      case 'wildberries':
        return '🟣';
      case 'ozon':
        return '🔵';
      case 'lamoda':
        return '🔴';
      case 'megamarket':
        return '🟢';
      case 'aliexpress':
        return '🟠';
      case 'avito':
        return '⚫';
      default:
        return '⚪';
    }
  }

  String get marketplaceName {
    switch (marketplace) {
      case 'wildberries':
        return 'Wildberries';
      case 'ozon':
        return 'Ozon';
      case 'lamoda':
        return 'Lamoda';
      case 'megamarket':
        return 'Мегамаркет';
      case 'aliexpress':
        return 'AliExpress';
      case 'avito':
        return 'Avito';
      default:
        return marketplace;
    }
  }

  // Ссылка для открытия — CPA если есть, иначе обычная
  String get openLink {
    if (trackingLink != null && trackingLink!.isNotEmpty) {
      return trackingLink!;
    }
    return deepLink;
  }

  // 🆕 Метод для создания копии с обновлёнными полями
  Product copyWith({
    String? id,
    String? name,
    double? price,
    double? oldPrice,
    String? imageUrl,
    double? rating,
    int? reviewCount,
    int? salesCount,
    String? deepLink,
    String? marketplace,
    DateTime? cachedAt,
    String? extractionMethod,
    String? trackingLink,
    double? commission,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      salesCount: salesCount ?? this.salesCount,
      deepLink: deepLink ?? this.deepLink,
      marketplace: marketplace ?? this.marketplace,
      cachedAt: cachedAt ?? this.cachedAt,
      extractionMethod: extractionMethod ?? this.extractionMethod,
      trackingLink: trackingLink ?? this.trackingLink,
      commission: commission ?? this.commission,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'oldPrice': oldPrice,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'salesCount': salesCount,
      'deepLink': deepLink,
      'marketplace': marketplace,
      'cachedAt': cachedAt.toIso8601String(),
      'extractionMethod': extractionMethod,
      'trackingLink': trackingLink,
      'commission': commission,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      oldPrice: (map['oldPrice'] as num?)?.toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: map['reviewCount'] ?? 0,
      salesCount: map['salesCount'] ?? 0,
      deepLink: map['deepLink'] ?? '',
      marketplace: map['marketplace'] ?? '',
      cachedAt: map['cachedAt'] != null 
          ? DateTime.parse(map['cachedAt']) 
          : DateTime.now(),
      extractionMethod: map['extractionMethod'] ?? 'selector',
      trackingLink: map['trackingLink'],
      commission: (map['commission'] as num?)?.toDouble(),
    );
  }
}
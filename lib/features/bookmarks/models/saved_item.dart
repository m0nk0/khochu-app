class SavedItem {
  final String id;
  final String name;
  final String marketplace;
  final String url;
  final String collection;
  final double targetPrice;

  SavedItem({required this.id, required this.name, required this.marketplace, required this.url, required this.collection, required this.targetPrice});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'marketplace': marketplace, 'url': url, 'collection': collection, 'targetPrice': targetPrice};

  factory SavedItem.fromJson(Map<String, dynamic> json) => SavedItem(
    id: json['id'], name: json['name'], marketplace: json['marketplace'], url: json['url'], collection: json['collection'], targetPrice: json['targetPrice'].toDouble()
  );
}
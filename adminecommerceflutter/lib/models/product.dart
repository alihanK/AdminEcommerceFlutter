class Product {
  final int id;
  final String name;
  final String? description;
  final double oldPrice;
  final double newPrice;
  final int stock;
  final int categoryId;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.oldPrice,
    required this.newPrice,
    required this.stock,
    required this.categoryId,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        oldPrice: (json['old_price'] as num).toDouble(),
        newPrice: (json['new_price'] as num).toDouble(),
        stock: (json['stock'] as int?) ?? 0,
        categoryId: json['category_id'] as int,
        imageUrl: json['image_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'old_price': oldPrice,
        'new_price': newPrice,
        'stock': stock,
        'category_id': categoryId,
        'image_url': imageUrl,
      };
}

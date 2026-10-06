class CategoryItem {
  final String id;
  final String name;
  final String imageUrl;
  final String? type;
  final String? restaurantId;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.type,
    this.restaurantId,
  });

  CategoryItem copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? type,
    String? restaurantId,
  }) {
    return CategoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      restaurantId: restaurantId ?? this.restaurantId,
    );
  }
}

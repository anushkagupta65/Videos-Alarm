class Category {
  final String name;
  final int number;

  Category({required this.name, required this.number});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      name: json['name'] ?? '',
      number: json['number'] ?? 0,
    );
  }
}

import 'check_item.dart';

/// 一份清单（导入的条目集合 + 标题）。
class Checklist {
  Checklist({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.items,
  });

  final String id;
  String title;
  final DateTime createdAt;
  final List<CheckItem> items;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory Checklist.fromJson(Map<String, dynamic> json) => Checklist(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        items: (json['items'] as List)
            .map((e) => CheckItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  CheckItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}

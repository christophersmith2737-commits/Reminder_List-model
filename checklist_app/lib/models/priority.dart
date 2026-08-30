/// 优先级三档，对应权重：必需 3 / 建议 2 / 日常 1。
enum Priority {
  required(3, '必需'),
  suggested(2, '建议'),
  daily(1, '日常');

  const Priority(this.weight, this.label);

  /// 权重值。
  final int weight;

  /// 中文显示名。
  final String label;

  /// 解析优先级。
  ///
  /// 接受（大小写不敏感）：
  /// - 中文档位：必需 / 必须 → 必需；推荐 / 建议 → 建议；适用 / 日常 → 日常
  /// - 英文：required / suggested / daily
  /// - 星数 1~5：★★★★★ / ⭐⭐⭐⭐ / 5★ / 5星 / ★5 / 纯数字 5
  ///   - 5★、4★ → 必需（权重 3）
  ///   - 3★、2★ → 建议（权重 2）
  ///   - 1★     → 日常（权重 1）
  /// 无法识别时返回 null。
  static Priority? parse(Object? raw) {
    if (raw == null) return null;
    if (raw is num) {
      return _fromStars(raw.toInt());
    }
    final s = raw.toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    switch (s) {
      case '必需':
      case '必须':
      case 'required':
        return Priority.required;
      case '建议':
      case '推荐':
      case 'suggested':
        return Priority.suggested;
      case '日常':
      case '适用':
      case 'daily':
        return Priority.daily;
    }
    // 星数形式：★★★★★ / ⭐⭐⭐ / 5★ / 5星 / ★5 / ⭐5 / 5
    final stars = _starsFromText(s);
    if (stars != null) {
      return _fromStars(stars);
    }
    return null;
  }

  /// 从 1~5 星映射到三档。
  static Priority? _fromStars(int stars) => switch (stars) {
        5 || 4 => Priority.required,
        3 || 2 => Priority.suggested,
        1 => Priority.daily,
        _ => null,
      };

  /// 从文本提取星数（1~5），无法识别返回 null。
  static int? _starsFromText(String s) {
    final t = s
        .replaceAll('⭐', '★')
        .replaceAll(' ', '')
        .replaceAll('\u00a0', '');
    // 纯星号串：★ 或 ★★★★★
    if (RegExp(r'^★+$').hasMatch(t)) {
      return t.length <= 5 ? t.length : null;
    }
    // 数字 + 星/星字：5★ / 5星
    final m1 = RegExp(r'^(\d+)[★星]?$').firstMatch(t);
    if (m1 != null) {
      final n = int.tryParse(m1.group(1)!);
      return (n != null && n >= 1 && n <= 5) ? n : null;
    }
    // 星 + 数字：★5 / ⭐5
    final m2 = RegExp(r'^[★星](\d+)$').firstMatch(t);
    if (m2 != null) {
      final n = int.tryParse(m2.group(1)!);
      return (n != null && n >= 1 && n <= 5) ? n : null;
    }
    return null;
  }

  /// JSON 序列化（存英文枚举名）。
  String toJson() => name;

  static Priority fromJson(String name) =>
      Priority.values.firstWhere((p) => p.name == name,
          orElse: () => Priority.daily);
}

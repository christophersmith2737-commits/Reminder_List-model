import '../widgets/trophy_pattern.dart';

/// 用户导入的虚拟像素成就。
///
/// 成就 = 一张像素图案（CSV，与奖杯同格式），
/// 可作为奖杯图案显示在追问页/结果页。
class Achievement {
  Achievement({
    required this.id,
    required this.name,
    required this.csv,
    required this.importedAt,
  });

  final String id;

  /// 成就名称（默认取文件名）。
  final String name;

  /// 原始 CSV 内容（含 TRANSPARENT 与颜色值）。
  final String csv;

  final DateTime importedAt;

  /// 解析后的图案（惰性，失败返回 null）。
  TrophyPattern? _pattern;

  TrophyPattern? get pattern {
    if (_pattern != null) return _pattern;
    try {
      _pattern = TrophyPattern.parse(csv);
    } catch (_) {
      return null;
    }
    return _pattern;
  }

  /// 尺寸校验：长（行）与宽（列）都不得超过 [maxCells]（默认 75）。
  /// 返回 null 表示通过；否则返回错误信息。
  static String? validateSize(String csv, {int maxCells = 75}) {
    try {
      final p = TrophyPattern.parse(csv);
      if (p.rows > maxCells || p.cols > maxCells) {
        return '图案尺寸 ${p.cols}×${p.rows} 超过限制 $maxCells×$maxCells 格';
      }
      if (p.totalPixels == 0) {
        return '图案中没有有效像素';
      }
      return null;
    } on FormatException catch (e) {
      return '无法解析：${e.message}';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'csv': csv,
        'importedAt': importedAt.toIso8601String(),
      };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        name: json['name'] as String? ?? '未命名成就',
        csv: json['csv'] as String,
        importedAt: DateTime.tryParse(json['importedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;

/// 奖杯像素图案数据。
///
/// 从拼豆图案 CSV（60 行 × 50 列）加载：
/// - 每格一个颜色值（如 #E99C17）或 TRANSPARENT（背景）
/// - 支持“按行从上到下逐格点亮”的进度计算（行优先的全局像素序号）
class TrophyPattern {
  TrophyPattern._(this.rows, this.cols, this.grid);

  final int rows;
  final int cols;

  /// grid[row][col]：null 表示透明背景。
  final List<List<Color?>> grid;

  /// 非透明像素总数。
  late final int totalPixels = _computeTotal();

  /// 每行的非透明像素数。
  late final List<int> rowPixelCounts = _computeRowCounts();

  /// rowOffsets[r] = 第 r 行之前所有非透明像素数（前缀和）。
  late final List<int> rowOffsets = _computeRowOffsets();

  /// 从 asset 加载。
  static Future<TrophyPattern> loadAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return parse(raw);
  }

  /// 解析 CSV 文本。
  static TrophyPattern parse(String csv) {
    final lines = csv
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final grid = <List<Color?>>[];
    for (final line in lines) {
      final cells = line.split(',');
      if (cells.length < 2) continue;
      grid.add(cells
          .map((c) => c.trim().toUpperCase() == 'TRANSPARENT'
              ? null
              : _parseColor(c.trim()))
          .toList());
    }
    if (grid.isEmpty) {
      throw const FormatException('奖杯图案为空');
    }
    final cols = grid.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    // 补齐行宽不一致的情况
    for (final row in grid) {
      while (row.length < cols) {
        row.add(null);
      }
    }
    return TrophyPattern._(grid.length, cols, grid);
  }

  static Color? _parseColor(String s) {
    if (s.isEmpty) return null;
    final hex = s.replaceFirst('#', '');
    final v = int.tryParse(hex, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  int _computeTotal() {
    var n = 0;
    for (final row in grid) {
      for (final cell in row) {
        if (cell != null) n++;
      }
    }
    return n;
  }

  List<int> _computeRowCounts() =>
      grid.map((row) => row.where((c) => c != null).length).toList();

  List<int> _computeRowOffsets() {
    final offs = List<int>.filled(rows + 1, 0);
    for (var r = 0; r < rows; r++) {
      offs[r + 1] = offs[r] + rowPixelCounts[r];
    }
    return offs;
  }

  /// 已点亮像素数（litFraction ∈ [0,1]，行优先从上到下）。
  int litPixels(double litFraction) =>
      (totalPixels * litFraction.clamp(0.0, 1.0)).round();

  /// 该格子是否已点亮。
  ///
  /// [litCount] 为当前已点亮像素总数；按行优先全局序号比较：
  /// 序号 < litCount 即点亮。O(col) 时间。
  bool isLit(int row, int col, int litCount) {
    final base = rowOffsets[row];
    // 该格之前的同行非透明格数
    var before = 0;
    for (var c = 0; c < col; c++) {
      if (grid[row][c] != null) before++;
    }
    return base + before < litCount;
  }
}

/// 奖杯图案的全局懒加载单例（两个页面共享同一份数据）。
class TrophyAssets {
  static const assetPath = 'assets/trophy/trophy.csv';
  static Future<TrophyPattern>? _future;

  static Future<TrophyPattern> load() =>
      _future ??= TrophyPattern.loadAsset(assetPath);
}

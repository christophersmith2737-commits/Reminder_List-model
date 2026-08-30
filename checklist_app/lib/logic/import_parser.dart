import 'dart:convert';

import '../models/check_item.dart';
import '../models/id_gen.dart';
import '../models/priority.dart';
import 'csv_parser.dart';

/// 导入解析结果。
class ImportResult {
  ImportResult({
    required this.title,
    required this.items,
    required this.skipped,
  });

  /// 清单标题。
  final String title;

  /// 解析出的条目（未回答状态）。
  final List<CheckItem> items;

  /// 因非法而被跳过的行数。
  final int skipped;

  /// 是否有至少一条有效条目。
  bool get isEmpty => items.isEmpty;
}

/// 清单导入解析器：支持 CSV 与 JSON。
class ImportParser {
  /// 根据内容自动识别格式并解析。
  ///
  /// [fallbackTitle] 用于 CSV（无标题）或 JSON 无 title 字段时，
  /// 通常传导入文件名（不含扩展名）。
  static ImportResult? parse({
    required String content,
    required String fallbackTitle,
  }) {
    // 去掉 UTF-8 BOM（Windows 导出的 CSV 常带 \uFEFF）
    var trimmed = content.trim();
    if (trimmed.startsWith('\uFEFF')) {
      trimmed = trimmed.substring(1).trim();
    }
    if (trimmed.isEmpty) return null;
    final first = trimmed.substring(0, 1);
    if (first == '{' || first == '[') {
      return _parseJson(trimmed, fallbackTitle);
    }
    return _parseCsv(trimmed, fallbackTitle);
  }

  // ---------------- CSV ----------------

  static ImportResult _parseCsv(String content, String fallbackTitle) {
    final rows = parseCsv(content);
    if (rows.isEmpty) {
      return ImportResult(title: fallbackTitle, items: const [], skipped: 0);
    }

    // 定位表头行：默认第一行；若第一行不是表头（工作流模板首行为任务总名称），
    // 则尝试第二行作为表头，第一行作为清单标题。
    var headerRow = 0;
    var title = fallbackTitle;
    if (!_isHeaderRow(rows[0]) && rows.length > 1 && _isHeaderRow(rows[1])) {
      headerRow = 1;
      final t = rows[0].firstWhere(
        (c) => c.trim().isNotEmpty,
        orElse: () => '',
      );
      if (t.trim().isNotEmpty) title = t.trim();
    }

    // 找表头列（支持中英文列名）
    final header =
        rows[headerRow].map((h) => h.trim().toLowerCase()).toList();
    int idxOf(Iterable<String> names) {
      for (final n in names) {
        final i = header.indexOf(n);
        if (i != -1) return i;
      }
      return -1;
    }

    final nameIdx = idxOf(['name', '名称', '任务名称', '物品名称', '物品']);
    final noteIdx = idxOf(['note', '备注', '任务备注', '说明']);
    final priorityIdx = idxOf(['priority', '优先级', '重要程度', '等级']);
    final quantityIdx = idxOf(['quantity', '数量', '个数']);
    if (nameIdx == -1 || priorityIdx == -1) {
      throw const FormatException(
          'CSV 表头需包含 name（名称）与 priority（优先级）列');
    }

    final items = <CheckItem>[];
    var skipped = 0;
    for (var r = headerRow + 1; r < rows.length; r++) {
      final row = rows[r];
      final name = nameIdx < row.length ? row[nameIdx].trim() : '';
      if (name.isEmpty) {
        skipped++;
        continue;
      }
      final rawPriority = priorityIdx < row.length ? row[priorityIdx] : '';
      final priority = Priority.parse(rawPriority);
      if (priority == null) {
        skipped++;
        continue;
      }
      final note = noteIdx >= 0 && noteIdx < row.length
          ? row[noteIdx].trim()
          : '';
      final quantity = quantityIdx >= 0 && quantityIdx < row.length
          ? row[quantityIdx].trim()
          : '';
      items.add(CheckItem(
        id: IdGen.next(),
        name: _mergeQuantity(name, quantity),
        note: note,
        priority: priority,
      ));
    }
    return ImportResult(
      title: title,
      items: items,
      skipped: skipped,
    );
  }

  /// 判断一行是否是表头行：包含名称类与优先级/等级类关键词。
  static bool _isHeaderRow(List<String> row) {
    final cells = row.map((c) => c.trim().toLowerCase()).toList();
    bool has(Iterable<String> names) =>
        names.any((n) => cells.contains(n));
    return has(['name', '名称', '物品名称', '任务名称', '物品']) &&
        has(['priority', '优先级', '重要程度', '等级']);
  }

  /// 把数量拼到名称后，如 “牛奶” + “2瓶” → “牛奶 ×2瓶”。
  /// 数量为空时保持原名。
  static String _mergeQuantity(String name, String quantity) {
    final q = quantity.trim();
    if (q.isEmpty) return name;
    return '$name ×$q';
  }

  // ---------------- JSON ----------------

  static ImportResult _parseJson(String content, String fallbackTitle) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      throw const FormatException('JSON 格式错误，请检查内容');
    }

    final List<dynamic> rawItems;
    String title = fallbackTitle;
    if (decoded is List) {
      rawItems = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final t = decoded['title'];
      if (t is String && t.trim().isNotEmpty) title = t.trim();
      final items = decoded['items'];
      if (items is List) {
        rawItems = items;
      } else {
        throw const FormatException('JSON 缺少 items 数组');
      }
    } else {
      throw const FormatException('JSON 顶层必须是对象或数组');
    }

    final items = <CheckItem>[];
    var skipped = 0;
    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) {
        skipped++;
        continue;
      }
      final name = raw['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        skipped++;
        continue;
      }
      final priority = Priority.parse(raw['priority']);
      if (priority == null) {
        skipped++;
        continue;
      }
      final note = raw['note']?.toString().trim() ?? '';
      final quantity = raw['quantity']?.toString().trim() ?? '';
      items.add(CheckItem(
        id: IdGen.next(),
        name: _mergeQuantity(name, quantity),
        note: note,
        priority: priority,
      ));
    }
    return ImportResult(title: title, items: items, skipped: skipped);
  }
}

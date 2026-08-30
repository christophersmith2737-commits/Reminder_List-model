/// 极简 CSV 解析器。
///
/// 支持：
/// - 逗号分隔字段
/// - 双引号包裹的字段（可含逗号、换行、双引号转义为 ""）
/// - 去掉每行末尾的 \r
library;

/// 解析 CSV 文本为行×列矩阵。
///
/// 返回空列表表示无有效数据。行内列数不足时补齐为空字符串。
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  final cell = StringBuffer();
  final row = <String>[];
  var inQuotes = false;
  var i = 0;

  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    // 跳过完全空白的行
    if (row.any((c) => c.trim().isNotEmpty)) {
      rows.add(List.of(row));
    }
    row.clear();
  }

  while (i < input.length) {
    final ch = input[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      cell.write(ch);
      i++;
      continue;
    }
    switch (ch) {
      case '"':
        inQuotes = true;
        i++;
      case ',':
        endCell();
        i++;
      case '\n':
        endRow();
        i++;
      case '\r':
        // 忽略，交给 \n 处理
        i++;
      default:
        cell.write(ch);
        i++;
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    endRow();
  }
  return rows;
}

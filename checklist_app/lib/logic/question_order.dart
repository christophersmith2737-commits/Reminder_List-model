import '../models/check_item.dart';
import '../models/priority.dart';

/// 追问顺序构建。
///
/// 规则：先全部“必需”，再“建议”，最后“日常”；
/// 同一档位内保持传入顺序（即导入顺序）。
class QuestionOrder {
  /// 构建完整清单的追问顺序。
  static List<CheckItem> buildAll(List<CheckItem> items) {
    return _ordered(items.where((e) => true).toList());
  }

  /// 只重新检查“否”（未完成）的条目，仍按优先级排序。
  static List<CheckItem> buildNotDoneOnly(List<CheckItem> items) {
    return _ordered(items.where((e) => !e.answer.countsAsDone).toList());
  }

  static List<CheckItem> _ordered(List<CheckItem> items) {
    items.sort((a, b) => b.priority.weight.compareTo(a.priority.weight));
    return items;
  }

  /// 供排序使用的优先级权重（必需 3 > 建议 2 > 日常 1）。
  static int weightOf(Priority p) => p.weight;
}

import '../models/answer_state.dart';
import '../models/check_item.dart';

/// 完成度统计。
///
/// 完成度 = 完成项目权重总和 ÷ 全部项目权重总和 × 100%
/// “是”和“不需要”都算完成，“否”不算。
class ProgressSummary {
  const ProgressSummary({
    required this.doneCount,
    required this.notDoneCount,
    required this.notNeededCount,
    required this.unansweredCount,
    required this.completedWeight,
    required this.totalWeight,
  });

  /// 已完成（是）项数。
  final int doneCount;

  /// 未完成（否）项数。
  final int notDoneCount;

  /// 不需要项数。
  final int notNeededCount;

  /// 未回答项数。
  final int unansweredCount;

  /// 计入完成的权重总和。
  final int completedWeight;

  /// 全部条目权重总和。
  final int totalWeight;

  int get totalCount =>
      doneCount + notDoneCount + notNeededCount + unansweredCount;

  /// 完成度百分比（四舍五入取整）。总权重为 0 时视为 0%。
  int get percent =>
      totalWeight == 0 ? 0 : (completedWeight * 100 / totalWeight).round();

  /// 所有选择“否”的条目（按优先级降序，同档保持原顺序）。
  List<CheckItem> notDoneItems(List<CheckItem> allItems) {
    final list =
        allItems.where((e) => e.answer == AnswerState.notDone).toList()
          ..sort((a, b) => b.priority.weight.compareTo(a.priority.weight));
    return list;
  }

  static ProgressSummary compute(List<CheckItem> items) {
    var done = 0, notDone = 0, notNeeded = 0, unanswered = 0;
    var completedWeight = 0, totalWeight = 0;
    for (final item in items) {
      totalWeight += item.priority.weight;
      switch (item.answer) {
        case AnswerState.done:
          done++;
          completedWeight += item.priority.weight;
        case AnswerState.notDone:
          notDone++;
        case AnswerState.notNeeded:
          notNeeded++;
          completedWeight += item.priority.weight;
        case AnswerState.unanswered:
          unanswered++;
      }
    }
    return ProgressSummary(
      doneCount: done,
      notDoneCount: notDone,
      notNeededCount: notNeeded,
      unansweredCount: unanswered,
      completedWeight: completedWeight,
      totalWeight: totalWeight,
    );
  }
}

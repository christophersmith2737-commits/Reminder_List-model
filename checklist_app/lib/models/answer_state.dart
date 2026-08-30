/// 条目回答状态。
///
/// - [unanswered] 未回答（默认）
/// - [done] 是（已完成）
/// - [notDone] 否（未完成）
/// - [notNeeded] 不需要（视为完成，但单独记录）
enum AnswerState {
  unanswered,
  done,
  notDone,
  notNeeded;

  /// 是否计入完成度（“是”与“不需要”都算完成）。
  bool get countsAsDone => this == done || this == notNeeded;

  bool get isAnswered => this != unanswered;

  String toJson() => name;

  static AnswerState fromJson(String name) =>
      AnswerState.values.firstWhere((s) => s.name == name,
          orElse: () => AnswerState.unanswered);
}

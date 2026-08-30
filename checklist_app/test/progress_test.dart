import 'package:checklist_tracker/logic/progress.dart';
import 'package:checklist_tracker/logic/question_order.dart';
import 'package:checklist_tracker/models/answer_state.dart';
import 'package:checklist_tracker/models/check_item.dart';
import 'package:checklist_tracker/models/priority.dart';
import 'package:flutter_test/flutter_test.dart';

CheckItem item(String id, Priority p,
        {AnswerState answer = AnswerState.unanswered}) =>
    CheckItem(id: id, name: id, priority: p, answer: answer);

void main() {
  group('QuestionOrder', () {
    test('必需→建议→日常，组内保持顺序', () {
      final items = [
        item('d1', Priority.daily),
        item('r1', Priority.required),
        item('s1', Priority.suggested),
        item('r2', Priority.required),
        item('d2', Priority.daily),
        item('s2', Priority.suggested),
      ];
      final order = QuestionOrder.buildAll(items);
      expect(order.map((e) => e.id).toList(),
          ['r1', 'r2', 's1', 's2', 'd1', 'd2']);
    });

    test('只重查未完成项，仍按优先级', () {
      final items = [
        item('d1', Priority.daily, answer: AnswerState.notDone),
        item('r1', Priority.required, answer: AnswerState.done),
        item('s1', Priority.suggested, answer: AnswerState.notDone),
        item('r2', Priority.required, answer: AnswerState.notNeeded),
        item('d2', Priority.daily, answer: AnswerState.notDone),
      ];
      final order = QuestionOrder.buildNotDoneOnly(items);
      expect(order.map((e) => e.id).toList(), ['s1', 'd1', 'd2']);
    });

    test('没有未完成项时返回空', () {
      final items = [
        item('r1', Priority.required, answer: AnswerState.done),
        item('d1', Priority.daily, answer: AnswerState.notNeeded),
      ];
      expect(QuestionOrder.buildNotDoneOnly(items), isEmpty);
    });
  });

  group('ProgressSummary', () {
    test('权重完成度计算：是/不需要算完成，否不算', () {
      // 必需2项(3+3) + 建议1项(2) + 日常2项(1+1) = 10
      final items = [
        item('r1', Priority.required, answer: AnswerState.done),
        item('r2', Priority.required, answer: AnswerState.notDone),
        item('s1', Priority.suggested, answer: AnswerState.notNeeded),
        item('d1', Priority.daily, answer: AnswerState.done),
        item('d2', Priority.daily, answer: AnswerState.notDone),
      ];
      final s = ProgressSummary.compute(items);
      expect(s.totalWeight, 10);
      expect(s.completedWeight, 3 + 2 + 1);
      expect(s.percent, 60);
      expect(s.doneCount, 2);
      expect(s.notDoneCount, 2);
      expect(s.notNeededCount, 1);
      expect(s.unansweredCount, 0);
    });

    test('全部完成 = 100%', () {
      final items = [
        item('r1', Priority.required, answer: AnswerState.done),
        item('s1', Priority.suggested, answer: AnswerState.done),
      ];
      expect(ProgressSummary.compute(items).percent, 100);
    });

    test('全部否 = 0%', () {
      final items = [
        item('r1', Priority.required, answer: AnswerState.notDone),
      ];
      expect(ProgressSummary.compute(items).percent, 0);
    });

    test('空清单 = 0% 且不崩溃', () {
      final s = ProgressSummary.compute(const []);
      expect(s.percent, 0);
      expect(s.totalCount, 0);
    });

    test('四舍五入', () {
      // 完成权重 1 / 总权重 3 = 33.33 → 33
      final items = [
        item('d1', Priority.daily, answer: AnswerState.notDone),
        item('d2', Priority.daily, answer: AnswerState.notDone),
        item('d3', Priority.daily, answer: AnswerState.done),
      ];
      expect(ProgressSummary.compute(items).percent, 33);
    });

    test('notDoneItems 按优先级降序返回', () {
      final items = [
        item('d1', Priority.daily, answer: AnswerState.notDone),
        item('r1', Priority.required, answer: AnswerState.notDone),
        item('s1', Priority.suggested, answer: AnswerState.notDone),
      ];
      final s = ProgressSummary.compute(items);
      expect(s.notDoneItems(items).map((e) => e.id).toList(),
          ['r1', 's1', 'd1']);
    });
  });
}

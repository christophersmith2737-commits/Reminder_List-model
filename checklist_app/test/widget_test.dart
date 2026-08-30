import 'package:checklist_tracker/data/app_state.dart';
import 'package:checklist_tracker/logic/import_parser.dart';
import 'package:checklist_tracker/models/answer_state.dart';
import 'package:checklist_tracker/models/priority.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleJson = '''
  {
    "title": "测试清单",
    "items": [
      {"name": "录取通知书", "priority": "必需"},
      {"name": "身份证", "priority": "必需"},
      {"name": "雨伞", "priority": "建议"},
      {"name": "充电宝", "priority": "日常"}
    ]
  }
  ''';

  test('导入→逐项追问→三按钮→完成度→重查 全流程', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.load();
    expect(state.screen, Screen.home);

    // 导入
    final result = ImportParser.parse(
        content: sampleJson, fallbackTitle: 't')!;
    await state.addPlan(result);
    expect(state.screen, Screen.question);
    expect(state.activePlan!.title, '测试清单');
    expect(state.hasSession, true);
    expect(state.plans.length, 1);

    // 追问顺序：必需→建议→日常
    final expected = ['录取通知书', '身份证', '雨伞', '充电宝'];
    for (var i = 0; i < expected.length; i++) {
      final name = expected[i];
      expect(state.currentItem!.name, name);
      state.answer(name == '身份证' ? AnswerState.notDone : AnswerState.done);
      // 最后一项答完后自动进入结果页
      if (i < expected.length - 1) {
        expect(state.screen, Screen.question);
      }
    }
    // 全部答完 → 结果页
    expect(state.screen, Screen.result);
    final s = state.summary;
    expect(s.doneCount, 3);
    expect(s.notDoneCount, 1);
    expect(s.notNeededCount, 0);
    // 权重：3+3+2+1=9，完成 3+2+1=6 → 67%（66.67 四舍五入）
    expect(s.percent, 67);

    // 未完成列表只有“身份证”
    final notDone = s.notDoneItems(state.activePlan!.items);
    expect(notDone.map((e) => e.name), ['身份证']);

    // 重新检查未完成项：只问“身份证”
    await state.startRecheck();
    expect(state.screen, Screen.question);
    expect(state.currentItem!.name, '身份证');
    expect(state.session!.itemIds.length, 1);

    // 重查时改为“不需要”
    state.answer(AnswerState.notNeeded);
    expect(state.screen, Screen.result);
    final s2 = state.summary;
    expect(s2.notDoneCount, 0);
    expect(s2.notNeededCount, 1);
    expect(s2.percent, 100);
  });

  test('数据持久化：重新 load 后清单与结果仍在', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.load();
    final result = ImportParser.parse(
        content: sampleJson, fallbackTitle: 't')!;
    await state.addPlan(result);
    state.answer(AnswerState.done);
    state.answer(AnswerState.notDone);
    // 只答两个就“关闭 APP”
    expect(state.screen, Screen.question);
    // 等异步持久化完成
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // 模拟重启
    final state2 = AppState();
    await state2.load();
    expect(state2.activePlan!.title, '测试清单');
    expect(state2.screen, Screen.question);
    expect(state2.currentItem!.name, '雨伞'); // 从第三个继续
    expect(state2.session!.currentIndex, 2);
    // 回答状态也必须保留（此前的 bug：重启后回答状态丢失 → 完成度 0%）
    final items = state2.activePlan!.items;
    expect(items[0].answer, AnswerState.done); // 录取通知书：是
    expect(items[1].answer, AnswerState.notDone); // 身份证：否
    expect(items[2].answer, AnswerState.unanswered); // 雨伞：未问
    expect(state2.summary.doneCount, 1);
    expect(state2.summary.notDoneCount, 1);
  });

  test('多计划：可导入多个，激活互不干扰，删除生效', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.load();

    final r1 = ImportParser.parse(content: sampleJson, fallbackTitle: 'A')!;
    await state.addPlan(r1);
    expect(state.plans.length, 1);
    final plan1Id = state.activePlan!.id;

    // 答一题后回首页，再导入第二个计划
    state.answer(AnswerState.done);
    state.goHome();
    final r2 = ImportParser.parse(
        content: '[{"name":"牛奶","priority":"必需"}]', fallbackTitle: 'B')!;
    await state.addPlan(r2);
    expect(state.plans.length, 2);
    expect(state.activePlan!.title, 'B');
    expect(state.screen, Screen.question);
    expect(state.currentItem!.name, '牛奶');

    // 切回计划 A：无进行中会话 → 结果页（可查进度）
    state.activatePlan(plan1Id);
    expect(state.screen, Screen.result);
    expect(state.summary.doneCount, 1);

    // 再来一次：重置后重新追问
    await state.restartPlan(plan1Id);
    expect(state.screen, Screen.question);
    expect(state.currentItem!.name, '录取通知书');
    expect(state.summary.unansweredCount, 4);
    expect(state.summary.doneCount, 0);

    // 删除计划 B
    final plan2Id = state.plans[1].id;
    await state.deletePlan(plan2Id);
    expect(state.plans.length, 1);
    expect(state.plans.first.title, '测试清单');
  });

  test('清空后回到首页且数据消失', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.load();
    final result = ImportParser.parse(
        content: sampleJson, fallbackTitle: 't')!;
    await state.addPlan(result);
    await state.clearAll();
    expect(state.hasPlans, false);
    expect(state.screen, Screen.home);

    final state2 = AppState();
    await state2.load();
    expect(state2.hasPlans, false);
  });

  test('旧数据迁移：单清单自动变为计划', () async {
    SharedPreferences.setMockInitialValues({});
    // 模拟旧版本存储（checklist_v1 key）
    final state = AppState();
    final result = ImportParser.parse(
        content: sampleJson, fallbackTitle: 't')!;
    await state.addPlan(result); // 写入 plans_v1
    // 手工写旧 key 模拟旧数据（新版本正常不会同时存在）
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('plans_v1');
    await prefs.setString('checklist_v1',
        '{"id":"legacy","title":"旧清单","createdAt":"2026-01-01T00:00:00.000","items":[]}');

    final state2 = AppState();
    await state2.load();
    expect(state2.plans.length, 1);
    expect(state2.plans.first.title, '旧清单');
  });

  test('优先级解析覆盖三档', () {
    expect(Priority.parse('必需'), Priority.required);
    expect(Priority.parse('建议'), Priority.suggested);
    expect(Priority.parse('日常'), Priority.daily);
  });
}

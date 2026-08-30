import 'package:checklist_tracker/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 端到端 UI 测试（真实设备/模拟器上运行）：
/// 首页 → 导入（粘贴 CSV）→ 确认 → 逐项追问（展开备注、三按钮）
/// → 结果页（完成度/统计/未完成列表）→ 重新检查未完成项。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const csv = '''
name,priority,note
录取通知书,必需,建议放在随身背包中。
身份证,必需,放在证件夹里。
雨伞,建议,今天预报有雨。
充电宝,日常,记得提前充满电。
''';

  /// 回答后等待：切换动画完成。
  Future<void> answerAndSettle(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('完整流程：导入→追问→结果→重查', (tester) async {
    // 清空本地数据，保证从空状态开始
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    app.main();
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // ---- 首页（空状态）----
    expect(find.text('还没有清单'), findsOneWidget);

    // ---- 进入导入页 ----
    await tester.tap(find.text('导入清单'));
    await tester.pumpAndSettle();
    expect(find.text('导入清单'), findsWidgets); // AppBar 标题

    // ---- 粘贴 CSV 并解析 ----
    await tester.enterText(find.byType(TextField), csv);
    await tester.tap(find.text('解析并预览'));
    await tester.pumpAndSettle();

    // ---- 确认导入 ----
    expect(find.textContaining('共 4 项'), findsOneWidget);
    await tester.tap(find.text('导入并开始'));
    await tester.pumpAndSettle();

    // ---- 追问页：第一次只显示第一项（必需）----
    expect(find.text('你是否携带了'), findsOneWidget);
    expect(find.text('录取通知书'), findsOneWidget);
    expect(find.text('身份证'), findsNothing); // 不会一次显示所有项
    // 进度 1/4
    expect(find.text('1 / 4'), findsOneWidget);

    // ---- 展开备注再收起 ----
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();
    expect(find.text('建议放在随身背包中。'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();
    expect(find.text('建议放在随身背包中。'), findsNothing);

    // ---- 回答：是（已完成）→ 下一项 ----
    await answerAndSettle(tester, '是');
    expect(find.text('身份证'), findsOneWidget);
    expect(find.text('2 / 4'), findsOneWidget);

    // ---- 回答：否（未完成）→ 下一项（建议）----
    await answerAndSettle(tester, '否');
    expect(find.text('雨伞'), findsOneWidget);
    expect(find.text('3 / 4'), findsOneWidget);

    // ---- 回答：不需要 → 下一项（日常）----
    await answerAndSettle(tester, '不需要');
    expect(find.text('充电宝'), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);

    // ---- 回答：是 → 全部完成，进入结果页 ----
    await answerAndSettle(tester, '是');
    expect(find.text('最终完成度'), findsOneWidget);
    // 权重：必需3+3 + 建议2 + 日常1 = 9；完成 3(是)+2(不需要)+1(是)=6 → 67%
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('未完成'), findsOneWidget);
    expect(find.text('不需要'), findsOneWidget);
    // 统计数字
    expect(find.text('2'), findsOneWidget); // 已完成 2
    expect(find.text('1'), findsWidgets); // 未完成 1（结果页标题区也可能有 1/4 之类）
    // 未完成列表列出“身份证”
    expect(find.text('身份证'), findsOneWidget);
    // 无未完成项时不显示庆祝卡，这里应显示重查按钮
    expect(find.text('重新检查未完成项'), findsOneWidget);

    // ---- 重新检查未完成项：只问“身份证” ----
    await tester.tap(find.text('重新检查未完成项'));
    await tester.pumpAndSettle();
    expect(find.text('你是否携带了'), findsOneWidget);
    expect(find.text('身份证'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    // 此时不应出现其他条目
    expect(find.text('雨伞'), findsNothing);

    // ---- 重查回答：不需要 → 结果页，完成度 100% ----
    await answerAndSettle(tester, '不需要');
    expect(find.text('最终完成度'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    // 未完成清零，显示庆祝卡
    expect(find.text('没有未完成的项目，太棒了！'), findsOneWidget);

    // ---- 回到首页：数据仍在 ----
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('当前清单'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });
}

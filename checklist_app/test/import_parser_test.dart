import 'package:checklist_tracker/logic/import_parser.dart';
import 'package:checklist_tracker/models/priority.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Priority.parse', () {
    test('中文', () {
      expect(Priority.parse('必需'), Priority.required);
      expect(Priority.parse('建议'), Priority.suggested);
      expect(Priority.parse('日常'), Priority.daily);
    });
    test('同义词：必须/推荐/适用', () {
      expect(Priority.parse('必须'), Priority.required);
      expect(Priority.parse('推荐'), Priority.suggested);
      expect(Priority.parse('适用'), Priority.daily);
    });
    test('英文（大小写不敏感）', () {
      expect(Priority.parse('REQUIRED'), Priority.required);
      expect(Priority.parse('Suggested'), Priority.suggested);
      expect(Priority.parse('daily'), Priority.daily);
    });
    test('数字', () {
      expect(Priority.parse(5), Priority.required);
      expect(Priority.parse(4), Priority.required);
      expect(Priority.parse(3), Priority.suggested);
      expect(Priority.parse('2'), Priority.suggested);
      expect(Priority.parse(1), Priority.daily);
    });
    test('星数 1~5 映射到三档', () {
      // 5★、4★ → 必需
      expect(Priority.parse('★★★★★'), Priority.required);
      expect(Priority.parse('⭐⭐⭐⭐'), Priority.required);
      expect(Priority.parse('5★'), Priority.required);
      expect(Priority.parse('5星'), Priority.required);
      expect(Priority.parse('★5'), Priority.required);
      expect(Priority.parse('4'), Priority.required);
      // 3★、2★ → 建议
      expect(Priority.parse('★★★'), Priority.suggested);
      expect(Priority.parse('2★'), Priority.suggested);
      expect(Priority.parse('3'), Priority.suggested);
      // 1★ → 日常
      expect(Priority.parse('★'), Priority.daily);
      expect(Priority.parse('1'), Priority.daily);
    });
    test('星数非法（超过 5 颗）返回 null', () {
      expect(Priority.parse('★★★★★★'), isNull);
      expect(Priority.parse('9'), isNull);
      expect(Priority.parse('0★'), isNull);
    });
    test('非法返回 null', () {
      expect(Priority.parse('紧急'), isNull);
      expect(Priority.parse(''), isNull);
      expect(Priority.parse(null), isNull);
    });
  });

  group('ImportParser CSV', () {
    test('标准 CSV', () {
      final r = ImportParser.parse(
        content: 'name,priority,note\n录取通知书,必需,放背包\n身份证,日常,\n',
        fallbackTitle: 'checklist',
      )!;
      expect(r.title, 'checklist');
      expect(r.items.length, 2);
      expect(r.items[0].name, '录取通知书');
      expect(r.items[0].priority, Priority.required);
      expect(r.items[0].note, '放背包');
      expect(r.skipped, 0);
    });

    test('跳过非法行并计数', () {
      final r = ImportParser.parse(
        content: 'name,priority,note\n有效,必需,x\n,必需,y\n无优先级,紧急,z\n',
        fallbackTitle: 't',
      )!;
      expect(r.items.length, 1);
      expect(r.skipped, 2);
    });

    test('缺表头抛异常', () {
      expect(
        () => ImportParser.parse(
            content: 'a,b\n1,2\n', fallbackTitle: 't'),
        throwsFormatException,
      );
    });

    test('数量列：英文表头 quantity 拼接到名称后', () {
      final r = ImportParser.parse(
        content: 'name,priority,note,quantity\n牛奶,必需,放冰箱,2瓶\n',
        fallbackTitle: 't',
      )!;
      expect(r.items.length, 1);
      expect(r.items[0].name, '牛奶 ×2瓶');
      expect(r.items[0].note, '放冰箱');
    });

    test('中文表头：物品名称/数量/备注/优先级', () {
      final r = ImportParser.parse(
        content: '物品名称,数量,备注,优先级\n牛奶,2瓶,放冰箱,必需\n雨伞,1把,,推荐\n',
        fallbackTitle: 't',
      )!;
      expect(r.items.length, 2);
      expect(r.items[0].name, '牛奶 ×2瓶');
      expect(r.items[0].priority, Priority.required);
      expect(r.items[0].note, '放冰箱');
      expect(r.items[1].name, '雨伞 ×1把');
      expect(r.items[1].priority, Priority.suggested);
    });

    test('含序号列：序号自动忽略', () {
      final r = ImportParser.parse(
        content: '序号,物品名称,数量,备注,优先级\n1,牛奶,2瓶,放冰箱,必需\n',
        fallbackTitle: 't',
      )!;
      expect(r.items.length, 1);
      expect(r.items[0].name, '牛奶 ×2瓶');
      expect(r.items[0].priority, Priority.required);
    });

    test('UTF-8 BOM 不影响解析', () {
      final r = ImportParser.parse(
        content: '\uFEFF物品名称,优先级\n牛奶,必需\n',
        fallbackTitle: 't',
      )!;
      expect(r.items.length, 1);
      expect(r.items[0].name, '牛奶');
    });

    test('工作流格式：首行总名称 + 第二行表头 + 星级优先级', () {
      final r = ImportParser.parse(
        content: '毕业论文工作流\n'
            '任务序号,优先级,任务名称,任务备注\n'
            '1,★★★★★,开题报告,周五 18:00 前提交导师\n'
            '2,★★★,文献综述,重点读近三年的论文\n'
            '3,★,整理笔记,有时间再做\n',
        fallbackTitle: 't',
      )!;
      expect(r.title, '毕业论文工作流'); // 首行作为清单标题
      expect(r.items.length, 3);
      expect(r.items[0].name, '开题报告');
      expect(r.items[0].priority, Priority.required); // 5★ → 必需
      expect(r.items[0].note, '周五 18:00 前提交导师');
      expect(r.items[1].priority, Priority.suggested); // 3★ → 建议
      expect(r.items[2].priority, Priority.daily); // 1★ → 日常
      expect(r.skipped, 0);
    });

    test('工作流格式：星数用数字写法 4/2/1', () {
      final r = ImportParser.parse(
        content: '交付上线工作流\n'
            '序号,重要程度,任务名称,备注\n'
            '1,5,代码评审,今天内完成\n'
            '2,2,写测试用例,覆盖核心路径\n'
            '3,1,整理文档,可选\n',
        fallbackTitle: 't',
      )!;
      expect(r.title, '交付上线工作流');
      expect(r.items[0].priority, Priority.required); // 5 → 必需
      expect(r.items[1].priority, Priority.suggested); // 2 → 建议
      expect(r.items[2].priority, Priority.daily); // 1 → 日常
    });

    test('数量列为空时名称不变', () {
      final r = ImportParser.parse(
        content: 'name,priority,quantity\n牛奶,必需,\n',
        fallbackTitle: 't',
      )!;
      expect(r.items[0].name, '牛奶');
    });
  });

  group('ImportParser JSON', () {
    test('对象结构带 title', () {
      final r = ImportParser.parse(
        content:
            '{"title":"开学清单","items":[{"name":"通知书","priority":"必需","note":"背包"}]}',
        fallbackTitle: 'fallback',
      )!;
      expect(r.title, '开学清单');
      expect(r.items.length, 1);
      expect(r.items[0].note, '背包');
    });

    test('数组结构，priority 用数字', () {
      final r = ImportParser.parse(
        content: '[{"name":"A","priority":5},{"name":"B","priority":3}]',
        fallbackTitle: 't',
      )!;
      expect(r.items.length, 2);
      expect(r.items[0].priority, Priority.required); // 5 → 必需
      expect(r.items[1].priority, Priority.suggested); // 3 → 建议
    });

    test('非法 JSON 抛异常', () {
      expect(
        () => ImportParser.parse(content: '{bad', fallbackTitle: 't'),
        throwsFormatException,
      );
    });

    test('缺 name 的条目跳过', () {
      final r = ImportParser.parse(
        content: '[{"priority":3},{"name":"B","priority":1}]',
        fallbackTitle: 't',
      )!;
      expect(r.items.length, 1);
      expect(r.skipped, 1);
    });
  });

  test('自动识别格式（CSV vs JSON）', () {
    final csv = ImportParser.parse(
        content: 'name,priority\nA,必需\n', fallbackTitle: 't')!;
    expect(csv.items.length, 1);
    final json = ImportParser.parse(
        content: '[{"name":"A","priority":"必需"}]', fallbackTitle: 't')!;
    expect(json.items.length, 1);
  });

  test('空内容返回 null', () {
    expect(ImportParser.parse(content: '   ', fallbackTitle: 't'), isNull);
  });
}

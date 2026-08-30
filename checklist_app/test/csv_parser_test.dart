import 'package:checklist_tracker/logic/csv_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCsv', () {
    test('解析基本行', () {
      final rows = parseCsv('a,b,c\n1,2,3\n');
      expect(rows, [
        ['a', 'b', 'c'],
        ['1', '2', '3'],
      ]);
    });

    test('解析带引号的字段（含逗号与换行）', () {
      final rows = parseCsv('name,note\n"录取,通知书","第一行\n第二行"\n');
      expect(rows[1][0], '录取,通知书');
      expect(rows[1][1], '第一行\n第二行');
    });

    test('解析引号转义（""）', () {
      final rows = parseCsv('a\n"他说""你好"""\n');
      expect(rows[1][0], '他说"你好"');
    });

    test('忽略空行', () {
      final rows = parseCsv('a,b\n\n\n1,2\n');
      expect(rows.length, 2);
    });

    test('行内列数不足时保留已有列', () {
      final rows = parseCsv('a,b,c\n1\n');
      expect(rows[1], ['1']);
    });

    test('空输入返回空列表', () {
      expect(parseCsv(''), isEmpty);
      expect(parseCsv('  \n '), isEmpty);
    });
  });
}

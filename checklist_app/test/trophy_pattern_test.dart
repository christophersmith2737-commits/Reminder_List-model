import 'package:checklist_tracker/widgets/trophy_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

const _sampleCsv = '''
TRANSPARENT,TRANSPARENT,TRANSPARENT
TRANSPARENT,#E99C17,#E99C17
#E99C17,#D98C39,TRANSPARENT
''';

void main() {
  group('TrophyPattern.parse', () {
    test('解析网格尺寸与颜色', () {
      final p = TrophyPattern.parse(_sampleCsv);
      expect(p.rows, 3);
      expect(p.cols, 3);
      // 非透明像素：4 个
      expect(p.totalPixels, 4);
      expect(p.rowPixelCounts, [0, 2, 2]);
      expect(p.rowOffsets, [0, 0, 2, 4]);
    });

    test('颜色解析正确（含 alpha 不透明）', () {
      final p = TrophyPattern.parse(_sampleCsv);
      final color = p.grid[1][1]!;
      expect(color.toARGB32() & 0xFFFFFF, 0xE99C17);
      expect(color.toARGB32() >> 24, 0xFF);
      expect(p.grid[0][0], isNull); // 透明
    });

    test('litPixels 按比例计算', () {
      final p = TrophyPattern.parse(_sampleCsv);
      expect(p.litPixels(0), 0);
      expect(p.litPixels(1), 4);
      expect(p.litPixels(0.5), 2);
      expect(p.litPixels(2.0), 4); // clamp
      expect(p.litPixels(-1), 0);
    });

    test('isLit 按行优先顺序点亮', () {
      final p = TrophyPattern.parse(_sampleCsv);
      // 全局顺序：(1,1),(1,2),(2,0),(2,1)
      // litCount=1 → 只亮 (1,1)
      expect(p.isLit(1, 1, 1), isTrue);
      expect(p.isLit(1, 2, 1), isFalse);
      expect(p.isLit(2, 0, 1), isFalse);
      // litCount=3 → 亮到 (2,0)
      expect(p.isLit(2, 0, 3), isTrue);
      expect(p.isLit(2, 1, 3), isFalse);
      // litCount=4 → 全亮
      expect(p.isLit(2, 1, 4), isTrue);
    });

    test('空输入抛异常', () {
      expect(() => TrophyPattern.parse(''), throwsFormatException);
    });
  });

  group('TrophyAssets', () {
    test('asset 路径存在（避免误改资源名）', () {
      expect(TrophyAssets.assetPath, 'assets/trophy/trophy.csv');
    });
  });
}

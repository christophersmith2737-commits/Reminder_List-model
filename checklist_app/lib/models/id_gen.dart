/// 通用小工具。
class IdGen {
  static int _seq = 0;

  /// 生成简单唯一 id（时间戳 + 自增序号）。
  static String next() {
    _seq++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }
}

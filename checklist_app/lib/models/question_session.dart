/// 一次逐项追问会话。
///
/// 记录追问顺序与当前进度。条目回答状态本身存在 [CheckItem.answer] 上，
/// 这里只记录“按什么顺序问、问到哪了”。
class QuestionSession {
  QuestionSession({
    required this.id,
    required this.checklistId,
    required this.itemIds,
    this.currentIndex = 0,
  });

  final String id;

  /// 对应的清单 id。
  final String checklistId;

  /// 追问顺序（条目 id 列表），必需 → 建议 → 日常，组内保持导入顺序。
  final List<String> itemIds;

  /// 当前追问到第几个（从 0 开始）。
  int currentIndex;

  bool get isFinished => currentIndex >= itemIds.length;

  String? get currentItemId =>
      isFinished ? null : itemIds[currentIndex];

  Map<String, dynamic> toJson() => {
        'id': id,
        'checklistId': checklistId,
        'itemIds': itemIds,
        'currentIndex': currentIndex,
      };

  factory QuestionSession.fromJson(Map<String, dynamic> json) =>
      QuestionSession(
        id: json['id'] as String,
        checklistId: json['checklistId'] as String,
        itemIds: (json['itemIds'] as List).cast<String>(),
        currentIndex: json['currentIndex'] as int? ?? 0,
      );
}

import 'answer_state.dart';
import 'priority.dart';

/// 清单中的一个检查条目。
class CheckItem {
  CheckItem({
    required this.id,
    required this.name,
    required this.priority,
    this.note = '',
    this.answer = AnswerState.unanswered,
    this.answeredAt,
  });

  final String id;

  /// 名称。
  final String name;

  /// 备注，可为空。
  final String note;

  /// 优先级。
  final Priority priority;

  /// 当前回答状态。
  AnswerState answer;

  /// 回答时间。
  DateTime? answeredAt;

  /// 是否有备注内容。
  bool get hasNote => note.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'note': note,
        'priority': priority.toJson(),
        'answer': answer.toJson(),
        'answeredAt': answeredAt?.toIso8601String(),
      };

  factory CheckItem.fromJson(Map<String, dynamic> json) => CheckItem(
        id: json['id'] as String,
        name: json['name'] as String,
        note: (json['note'] as String?) ?? '',
        priority: Priority.fromJson(json['priority'] as String),
        answer: AnswerState.fromJson(json['answer'] as String? ?? 'unanswered'),
        answeredAt: json['answeredAt'] != null
            ? DateTime.tryParse(json['answeredAt'] as String)
            : null,
      );
}

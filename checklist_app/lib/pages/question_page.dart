import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/answer_state.dart';
import '../models/priority.dart';
import '../widgets/trophy_pattern.dart';
import '../widgets/trophy_view.dart';

/// 逐项追问页面：一次只显示一个条目，由 APP 主动询问。
class QuestionPage extends StatefulWidget {
  const QuestionPage({super.key, required this.state});

  final AppState state;

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  bool _noteExpanded = false;
  TrophyPattern? _trophy;

  @override
  void initState() {
    super.initState();
    _loadTrophy();
  }

  Future<void> _loadTrophy() async {
    try {
      final t = await TrophyAssets.load();
      if (mounted) setState(() => _trophy = t);
    } catch (_) {
      // 加载失败则保持无奖杯（不阻塞追问流程）
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final item = state.currentItem;
    final theme = Theme.of(context);

    if (item == null) {
      // 理论不会到这里（根页面会在会话结束时切走），兜底
      return const Scaffold(body: SizedBox.shrink());
    }

    // 奖杯图案：优先用用户导入的成就，否则内置奖杯
    final achievement = state.activeAchievement;
    final trophy = achievement?.pattern ?? _trophy;

    return Scaffold(
      appBar: AppBar(
        title: Text(state.progressText),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: '回到首页',
          onPressed: () => state.goHome(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _PriorityBadge(priority: item.priority)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // 奖杯：50% 半透明剪影 + 实时完成百分数
                    if (trophy != null)
                      TrophyView(
                        pattern: trophy,
                        litFraction: 0,
                        percent: state.summary.percent,
                        size: const Size(150, 180),
                      )
                    else
                      Icon(Icons.emoji_events_outlined,
                          size: 56, color: theme.colorScheme.primary),
                    const SizedBox(height: 24),
                    Text(
                      '你是否携带了',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.hasNote) ...[
                      const SizedBox(height: 16),
                      // 备注展开/收起箭头
                      InkWell(
                        onTap: () =>
                            setState(() => _noteExpanded = !_noteExpanded),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedRotation(
                                turns: _noteExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 32,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                child: _noteExpanded
                                    ? Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme
                                              .secondaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          item.note,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      )
                                    : const SizedBox(width: double.infinity),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 底部固定三个按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _answer(AnswerState.done),
                      child: const Text('是',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _answer(AnswerState.notDone),
                      child: const Text('否',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _answer(AnswerState.notNeeded),
                      child: const Text('不需要',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _answer(AnswerState answer) {
    final item = widget.state.currentItem;
    if (item == null) return;
    // 记录回答并立即进入下一项（不弹 SnackBar，避免遮挡底部按钮）
    widget.state.answer(answer);
    setState(() => _noteExpanded = false);
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (priority) {
      Priority.required => (scheme.errorContainer, scheme.onErrorContainer),
      Priority.suggested => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      Priority.daily => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priority.label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

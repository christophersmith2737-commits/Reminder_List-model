import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/check_item.dart';
import '../widgets/trophy_pattern.dart';
import '../widgets/trophy_view.dart';

/// 结果页：最终完成度、奖杯点亮动画、统计、未完成列表、重新检查入口。
class ResultPage extends StatefulWidget {
  const ResultPage({super.key, required this.state});

  final AppState state;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  TrophyPattern? _trophy;

  @override
  void initState() {
    super.initState();
    TrophyAssets.load().then((t) {
      if (mounted) setState(() => _trophy = t);
    }).catchError((_) {
      // 加载失败则无奖杯动画，仅显示文字
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final checklist = state.activePlan;
    final summary = state.summary;

    if (checklist == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final notDoneItems = summary.notDoneItems(checklist.items);
    final hasNotDone = notDoneItems.isNotEmpty;

    // 奖杯图案：优先用用户导入的成就，否则内置奖杯
    final achievement = state.activeAchievement;
    final trophy = achievement?.pattern ?? _trophy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('检查结果'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: '回到首页',
          onPressed: () => state.goHome(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          // 奖杯点亮动画 + 最终完成度
          Center(
            child: Column(
              children: [
                if (trophy != null)
                  TrophyReveal(
                    pattern: trophy,
                    targetPercent: summary.percent,
                    size: const Size(200, 240),
                  )
                else ...[
                  Text(
                    '最终完成度',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${summary.percent}%',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '完成权重 ${summary.completedWeight} / 总权重 ${summary.totalWeight}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 三项统计
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  _CountItem(
                    label: '已完成',
                    value: summary.doneCount,
                    color: Colors.green,
                  ),
                  _CountItem(
                    label: '未完成',
                    value: summary.notDoneCount,
                    color: Colors.redAccent,
                  ),
                  _CountItem(
                    label: '不需要',
                    value: summary.notNeededCount,
                    color: theme.colorScheme.tertiary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 未完成列表
          if (hasNotDone) ...[
            Text('未完成的项目', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < notDoneItems.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _NotDoneTile(item: notDoneItems[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '以上 ${notDoneItems.length} 项选择了“否”',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.celebration_outlined,
                        color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '没有未完成的项目，太棒了！',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          // 重新检查未完成项
          if (hasNotDone)
            FilledButton.icon(
              onPressed: () => state.startRecheck(),
              icon: const Icon(Icons.refresh),
              label: const Text('重新检查未完成项'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountItem extends StatelessWidget {
  const _CountItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotDoneTile extends StatelessWidget {
  const _NotDoneTile({required this.item});

  final CheckItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(Icons.cancel_outlined, color: Colors.redAccent),
      title: Text(item.name),
      subtitle: item.hasNote ? Text(item.note, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
      trailing: Text(
        item.priority.label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

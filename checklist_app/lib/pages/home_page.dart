import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/progress.dart';
import '../models/achievement.dart';
import '../models/checklist.dart';
import '../models/priority.dart';
import '../widgets/trophy_view.dart';
import 'achievements_page.dart';
import 'import_page.dart';

/// 首页：显示已导入的计划列表，含侧边栏与“+”导入入口。
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final plans = state.plans;

    return Scaffold(
      appBar: AppBar(
        title: const Text('清单追踪'),
        centerTitle: true,
        actions: [
          if (plans.isNotEmpty)
            IconButton(
              tooltip: '清空数据',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmClear(context),
            ),
        ],
      ),
      drawer: _buildDrawer(context),
      floatingActionButton: FloatingActionButton(
        tooltip: '导入计划',
        onPressed: () => _goImport(context),
        child: const Icon(Icons.add),
      ),
      body: plans.isEmpty
          ? _EmptyView(onImport: () => _goImport(context))
          : _PlanList(state: state, plans: plans),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题区 + 收藏品 + “+”按钮
            Container(
              color: theme.colorScheme.primaryContainer,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.checklist_rounded,
                          size: 32, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('清单追踪',
                            style: theme.textTheme.titleLarge),
                      ),
                      // 收藏品“+”按钮（最多 5 个）
                      IconButton(
                        tooltip: '添加收藏品',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _pickCollection(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 收藏品展示：1 个正常摆放，多个扑克牌旋转叠加
                  _CollectionFan(state: state),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('导入虚拟像素成就'),
              subtitle: const Text('CSV 图案，长宽不超过 75 格'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => AchievementsPage(state: state)),
                );
              },
            ),
            // 主题切换
            ListTile(
              leading: Icon(state.themeMode == ThemeMode.dark
                  ? Icons.dark_mode
                  : Icons.light_mode),
              title: const Text('主题'),
              trailing: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('白天')),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('夜晚')),
                ],
                selected: {state.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => state.setThemeMode(s.first),
              ),
            ),
            const Divider(),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('版本 1.2.0'),
              subtitle: const Text('作者：Harlemonica'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 弹出成就挑选对话框（多选加入收藏，最多 5 个）。
  Future<void> _pickCollection(BuildContext context) async {
    final state = this.state;
    final available =
        state.achievements.where((a) => a.pattern != null).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有成就，请先导入虚拟像素成就')),
      );
      return;
    }
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _CollectionPicker(state: state, available: available),
    );
    if (selected == null || !context.mounted) return;
    // 依次添加
    for (final id in selected) {
      state.addToCollection(id);
    }
  }

  void _goImport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImportPage(state: state),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空数据'),
        content: const Text('将删除本地的所有计划、回答结果与成就，确定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.clearAll();
    }
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist_rounded,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('还没有计划', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '点击右下角 + 导入 CSV 或 JSON 计划，\n开始逐项追问检查',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// 计划列表：每个计划可打开查验进度、重来一次、删除。
class _PlanList extends StatelessWidget {
  const _PlanList({required this.state, required this.plans});

  final AppState state;
  final List<Checklist> plans;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        return _PlanCard(state: state, plan: plan);
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.state, required this.plan});

  final AppState state;
  final Checklist plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = ProgressSummary.compute(plan.items);
    final isFinished = summary.unansweredCount == 0;
    final inProgress = !isFinished && summary.totalCount > 0;
    final counts = _countByPriority(plan);

    final (Color bg, Color fg, String label) = isFinished
        ? (Colors.green.shade50, Colors.green.shade800, '已完成')
        : inProgress
            ? (Colors.blue.shade50, Colors.blue.shade800, '进行中')
            : (theme.colorScheme.surfaceContainerHighest,
                theme.colorScheme.onSurfaceVariant, '未开始');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => state.activatePlan(plan.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(plan.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            color: fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '共 ${plan.items.length} 项 · 必需 ${counts[Priority.required]} · '
                '推荐 ${counts[Priority.suggested]} · 适用 ${counts[Priority.daily]}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // 完成度条
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: summary.totalWeight == 0
                            ? 0
                            : summary.completedWeight / summary.totalWeight,
                        minHeight: 8,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${summary.percent}%',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: '更多操作',
                    onSelected: (v) {
                      if (v == 'restart') {
                        _confirmRestart(context);
                      } else if (v == 'delete') {
                        _confirmDelete(context);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'restart', child: Text('再来一次')),
                      PopupMenuItem(value: 'delete', child: Text('删除计划')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<Priority, int> _countByPriority(Checklist checklist) {
    final map = {for (final p in Priority.values) p: 0};
    for (final item in checklist.items) {
      map[item.priority] = map[item.priority]! + 1;
    }
    return map;
  }

  Future<void> _confirmRestart(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('再来一次？'),
        content: Text('将重置「${plan.title}」的所有回答，重新开始逐项追问。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('开始'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.restartPlan(plan.id);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除计划'),
        content: Text('确定删除「${plan.title}」吗？回答结果将一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.deletePlan(plan.id);
    }
  }
}

/// 收藏品展示区：1 个正常摆放，多个像扑克牌一样旋转叠加。
class _CollectionFan extends StatelessWidget {
  const _CollectionFan({required this.state});

  final AppState state;

  static const _cardSize = Size(64, 64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collected = state.collectedAchievements;

    if (collected.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '收藏品（最多 5 个）',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final n = collected.length;
    return SizedBox(
      height: _cardSize.height + 16,
      child: Stack(
        children: [
          for (var i = 0; i < n; i++)
            Positioned(
              left: i * 18.0,
              top: 8,
              child: Transform.rotate(
                // 单个正常摆放；多个像扑克牌扇形散开
                angle: n == 1 ? 0 : _fanAngle(n, i),
                child: _CollectionCard(
                  achievement: collected[i],
                  size: _cardSize,
                  onRemove: () =>
                      state.removeFromCollection(collected[i].id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 扑克牌扇形角度：中间平、两边向外旋。
  static double _fanAngle(int n, int i) {
    final spread = 0.24; // 最大弧度约 ±14°
    if (n == 1) return 0;
    final center = (n - 1) / 2;
    return (i - center) * spread;
  }
}

/// 单张收藏品卡片（像素图案 + 名称；长按/点击删除）。
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.achievement,
    required this.size,
    required this.onRemove,
  });

  final Achievement achievement;
  final Size size;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pattern = achievement.pattern;
    return Tooltip(
      message: '${achievement.name}\n点击移除',
      child: InkWell(
        onTap: () => _confirmRemove(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2)),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: pattern == null
              ? const Icon(Icons.broken_image_outlined, size: 20)
              : TrophyView(
                  pattern: pattern,
                  litFraction: 1.0,
                  showPercent: false,
                  size: const Size(52, 52),
                  cellGap: 0,
                ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除收藏品'),
        content: Text('将「${achievement.name}」从收藏中移除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      onRemove();
    }
  }
}

/// 成就挑选弹窗（从成就库中勾选加入收藏，最多 5 个）。
class _CollectionPicker extends StatefulWidget {
  const _CollectionPicker({required this.state, required this.available});

  final AppState state;
  final List<Achievement> available;

  @override
  State<_CollectionPicker> createState() => _CollectionPickerState();
}

class _CollectionPickerState extends State<_CollectionPicker> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('选择收藏品（${_selected.length}/5）',
                      style: theme.textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected.toList()),
                  child: const Text('加入收藏'),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.available.length,
              itemBuilder: (context, index) {
                final a = widget.available[index];
                final already = widget.state.isCollected(a.id);
                final checked = _selected.contains(a.id);
                final full = widget.state.isCollectionFull &&
                    !already && !checked;
                return CheckboxListTile(
                  value: checked || already,
                  onChanged: already || full
                      ? null
                      : (v) {
                          if (v == true) {
                            if (_selected.length >= 5) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('收藏品最多 5 个')),
                              );
                              return;
                            }
                            setState(() => _selected.add(a.id));
                          } else {
                            setState(() => _selected.remove(a.id));
                          }
                        },
                  secondary: SizedBox(
                    width: 40,
                    height: 40,
                    child: a.pattern == null
                        ? const Icon(Icons.broken_image_outlined, size: 20)
                        : TrophyView(
                            pattern: a.pattern!,
                            litFraction: 1.0,
                            showPercent: false,
                            size: const Size(40, 40),
                            cellGap: 0,
                          ),
                  ),
                  title: Text(a.name),
                  subtitle: already ? const Text('已在收藏中') : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

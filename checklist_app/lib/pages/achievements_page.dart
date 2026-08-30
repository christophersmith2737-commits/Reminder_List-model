import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/achievement.dart';
import '../widgets/trophy_pattern.dart';
import '../widgets/trophy_view.dart';

/// 成就库页面：导入虚拟像素成就（CSV）、预览、设为当前奖杯、删除。
class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key, required this.state});

  final AppState state;

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  bool _busy = false;

  Future<void> _pickAndImport() async {
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (files.isEmpty) return;
      final file = files.first;
      final String csv;
      final String name;
      if (file.path != null) {
        csv = await File(file.path!).readAsString();
      } else {
        csv = String.fromCharCodes(await file.readAsBytes());
      }
      name = file.name.contains('.')
          ? file.name.substring(0, file.name.lastIndexOf('.'))
          : file.name;

      // 尺寸校验：长宽不超过 75 格，超限弹窗阻止
      final err = Achievement.validateSize(csv);
      if (err != null) {
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('无法导入成就'),
              content: Text(err),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final importErr = widget.state.importAchievement(name: name, csv: csv);
      if (importErr != null && mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('无法导入成就'),
            content: Text(importErr),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成就「$name」导入成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('读取文件失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achievements = widget.state.achievements;
    final activeId = widget.state.activeAchievement?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('虚拟像素成就'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _pickAndImport,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.file_open_outlined),
        label: const Text('导入 CSV'),
      ),
      body: achievements.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 72, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('还没有成就', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      '导入像素图案 CSV（长宽不超过 75 格），\n即可用作奖杯图案。',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                final a = achievements[index];
                final pattern = a.pattern;
                return _AchievementCard(
                  achievement: a,
                  pattern: pattern,
                  isActive: a.id == activeId,
                  onUse: pattern != null
                      ? () {
                          widget.state.setActiveAchievement(a.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已将「${a.name}」设为奖杯图案')),
                          );
                        }
                      : null,
                  onDelete: () => _confirmDelete(context, a),
                );
              },
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Achievement a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除成就'),
        content: Text('确定删除「${a.name}」吗？'),
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
      await widget.state.deleteAchievement(a.id);
    }
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    required this.pattern,
    required this.isActive,
    required this.onUse,
    required this.onDelete,
  });

  final Achievement achievement;
  final TrophyPattern? pattern;
  final bool isActive;
  final VoidCallback? onUse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: isActive
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: Column(
        children: [
          Expanded(
            child: pattern == null
                ? const Center(child: Icon(Icons.broken_image_outlined))
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: TrophyView(
                      pattern: pattern!,
                      litFraction: 1.0,
                      showPercent: false,
                      size: const Size(120, 120),
                      cellGap: 0,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              children: [
                Text(
                  achievement.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('使用中',
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    theme.colorScheme.onPrimaryContainer)),
                      )
                    else
                      TextButton(
                        onPressed: onUse,
                        child: const Text('设为奖杯'),
                      ),
                    IconButton(
                      tooltip: '删除',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

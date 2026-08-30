import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../logic/import_parser.dart';

/// 导入页面：选择文件（CSV/JSON）或粘贴文本。
class ImportPage extends StatefulWidget {
  const ImportPage({super.key, required this.state});

  final AppState state;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final _textController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'json'],
      );
      if (files.isEmpty) return;
      final file = files.first;
      final path = file.path;
      if (path == null) {
        // 无法拿到本地路径时直接读字节
        final bytes = await file.readAsBytes();
        final content = String.fromCharCodes(bytes);
        _doImport(content, _titleFromName(file.name));
        return;
      }
      final content = await File(path).readAsString();
      _doImport(content, _titleFromName(file.name));
    } catch (e) {
      _showError('读取文件失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _titleFromName(String name) =>
      name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;

  void _doImport(String content, String title) {
    try {
      final result = ImportParser.parse(content: content, fallbackTitle: title);
      if (result == null || result.isEmpty) {
        _showError('没有解析到任何有效条目');
        return;
      }
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认导入'),
          content: Text(
            '清单「${result.title}」\n'
            '共 ${result.items.length} 项'
            '${result.skipped > 0 ? '（跳过 ${result.skipped} 条无效数据）' : ''}\n\n'
            '导入后将开始逐项追问。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmImport(result);
              },
              child: const Text('导入并开始'),
            ),
          ],
        ),
      );
    } on FormatException catch (e) {
      _showError(e.message.toString());
    }
  }

  Future<void> _confirmImport(ImportResult result) async {
    await widget.state.addPlan(result);
    if (!mounted) return;
    // 回到根页面：根页面按 state.screen 自动切到追问页
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('导入清单'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('选择文件', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '支持 CSV 或 JSON 文件。\n'
                    'CSV 表头：name, priority, note\n'
                    'priority 取值：必需 / 建议 / 日常（或 required / suggested / daily）',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _pickFile,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open),
                    label: const Text('选择文件'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('粘贴内容', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '也可以直接把 CSV 或 JSON 文本粘贴到这里。',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: '在此粘贴 CSV 或 JSON 内容…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      final text = _textController.text.trim();
                      if (text.isEmpty) {
                        _showError('请先粘贴内容');
                        return;
                      }
                      _doImport(text, '粘贴清单');
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('解析并预览'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

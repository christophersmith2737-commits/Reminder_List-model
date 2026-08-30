import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../logic/import_parser.dart';
import '../logic/progress.dart';
import '../logic/question_order.dart';
import '../models/achievement.dart';
import '../models/answer_state.dart';
import '../models/check_item.dart';
import '../models/checklist.dart';
import '../models/id_gen.dart';
import '../models/question_session.dart';
import 'storage.dart';

/// 全局应用状态（单例）。
///
/// 管理：计划列表（多清单）、当前激活计划、追问会话、成就库；
/// 所有修改自动持久化。页面通过 [ListenableBuilder] 监听刷新。
class AppState extends ChangeNotifier {
  AppState({AppStorage? storage}) : _storage = storage ?? AppStorage();

  final AppStorage _storage;

  List<Checklist> _plans = [];
  String? _activePlanId;
  List<Achievement> _achievements = [];
  String? _activeAchievementId;
  List<String> _collectedIds = [];
  ThemeMode _themeMode = ThemeMode.light;
  QuestionSession? _session;

  /// 页面模式。
  Screen _screen = Screen.home;

  List<Checklist> get plans => List.unmodifiable(_plans);
  List<Achievement> get achievements => List.unmodifiable(_achievements);

  /// 收藏的成就 id 列表（最多 5 个，按添加顺序）。
  List<String> get collectedIds => List.unmodifiable(_collectedIds);

  ThemeMode get themeMode => _themeMode;

  /// 收藏品（按添加顺序解析出的成就）。
  List<Achievement> get collectedAchievements {
    final result = <Achievement>[];
    for (final id in _collectedIds) {
      for (final a in _achievements) {
        if (a.id == id) {
          result.add(a);
          break;
        }
      }
    }
    return result;
  }

  bool get isCollectionFull => _collectedIds.length >= 5;

  bool isCollected(String achievementId) => _collectedIds.contains(achievementId);

  /// 当前激活的计划（首页点击/导入后设置）。
  Checklist? get activePlan {
    for (final p in _plans) {
      if (p.id == _activePlanId) return p;
    }
    return null;
  }

  /// 当前使用的奖杯图案（成就）。未设置时返回 null（用内置奖杯）。
  Achievement? get activeAchievement {
    for (final a in _achievements) {
      if (a.id == _activeAchievementId) return a;
    }
    return null;
  }

  QuestionSession? get session => _session;
  Screen get screen => _screen;

  bool get hasPlans => _plans.isNotEmpty;
  bool get hasSession => _session != null;

  /// 当前追问条目。
  CheckItem? get currentItem {
    final s = _session;
    final plan = activePlan;
    if (s == null || plan == null || s.isFinished) return null;
    return plan.itemById(s.currentItemId!);
  }

  /// 当前追问进度文本，如 “3 / 12”。
  String get progressText {
    final s = _session;
    if (s == null) return '';
    return '${(s.currentIndex + 1).clamp(1, s.itemIds.length)} / ${s.itemIds.length}';
  }

  /// 从本地恢复数据。
  Future<void> load() async {
    _plans = await _storage.loadPlans();
    _achievements = await _storage.loadAchievements();
    _activeAchievementId = await _storage.loadActiveAchievementId();
    _collectedIds = await _storage.loadCollectedAchievementIds();
    _themeMode = _parseThemeMode(await _storage.loadThemeMode());
    _activePlanId = await _storage.loadActivePlanId();
    if (_activePlanId != null && activePlan == null) {
      _activePlanId = null;
    }
    _session = await _storage.loadSession();
    // 会话失效（计划被删除）时丢弃
    if (activePlan != null &&
        _session != null &&
        _session!.checklistId != activePlan!.id) {
      _session = null;
    }
    if (_session != null && _session!.isFinished) {
      _screen = Screen.result;
    } else if (_session != null && activePlan != null) {
      _screen = Screen.question;
    } else if (activePlan != null && _session == null) {
      _screen = Screen.home;
    }
    notifyListeners();
  }

  static ThemeMode _parseThemeMode(String? s) => switch (s) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.light,
      };

  // ---------------- 计划 ----------------

  /// 导入新计划（追加到列表并激活，随后进入逐项追问）。
  Future<void> addPlan(ImportResult result) async {
    final plan = Checklist(
      id: IdGen.next(),
      title: result.title,
      createdAt: DateTime.now(),
      items: result.items,
    );
    _plans.add(plan);
    await _persistPlans();
    activatePlan(plan.id);
    _startSession(QuestionOrder.buildAll(plan.items));
  }

  /// 激活某个计划（从首页点击进入）。
  ///
  /// - 有进行中会话 → 追问页
  /// - 已完成会话 → 结果页
  /// - 无会话（从未开始或已完成并回首页）→ 结果页（可查进度）
  void activatePlan(String planId) {
    if (activePlan?.id == planId) {
      final s = _session;
      if (s != null) {
        _screen = s.isFinished ? Screen.result : Screen.question;
      } else {
        _screen = Screen.result;
      }
      notifyListeners();
      return;
    }
    _activePlanId = planId;
    _session = null;
    _screen = Screen.result;
    notifyListeners();
    unawaited(_persistActive());
  }

  /// 重新检查未完成项：只追问“否”的条目。
  Future<void> startRecheck() async {
    final plan = activePlan;
    if (plan == null) return;
    final items = QuestionOrder.buildNotDoneOnly(plan.items);
    if (items.isEmpty) {
      // 没有未完成项，直接回到结果页
      _screen = Screen.result;
      notifyListeners();
      return;
    }
    _startSession(items);
  }

  /// “再来一次”：重置当前计划所有回答状态，重新开始完整追问。
  Future<void> restartPlan(String planId) async {
    final plan = _plans.where((p) => p.id == planId).firstOrNull;
    if (plan == null) return;
    for (final item in plan.items) {
      item.answer = AnswerState.unanswered;
      item.answeredAt = null;
    }
    await _persistPlans();
    _activePlanId = planId;
    _startSession(QuestionOrder.buildAll(plan.items));
  }

  /// 删除计划。
  Future<void> deletePlan(String planId) async {
    _plans.removeWhere((p) => p.id == planId);
    if (_activePlanId == planId) {
      _activePlanId = null;
      _session = null;
      _screen = Screen.home;
    }
    await _persistPlans();
    await _persistSession();
    await _storage.saveActivePlanId(_activePlanId);
    notifyListeners();
  }

  void _startSession(List<CheckItem> orderedItems) {
    final plan = activePlan;
    if (plan == null) return;
    _session = QuestionSession(
      id: IdGen.next(),
      checklistId: plan.id,
      itemIds: orderedItems.map((e) => e.id).toList(),
    );
    _screen = Screen.question;
    notifyListeners();
    unawaited(_persistSession());
  }

  /// 回答当前条目（是 / 否 / 不需要），自动进入下一项。
  void answer(AnswerState state) {
    final s = _session;
    final plan = activePlan;
    final item = currentItem;
    if (s == null || plan == null || item == null) return;

    item.answer = state;
    item.answeredAt = DateTime.now();
    s.currentIndex++;
    if (s.isFinished) {
      _screen = Screen.result;
    }
    notifyListeners();
    unawaited(_persistAll());
  }

  /// 继续：会话未完成则回到追问页，已完成则回到结果页。
  void resume() {
    final s = _session;
    if (s == null) return;
    _screen = s.isFinished ? Screen.result : Screen.question;
    notifyListeners();
  }

  /// 回到首页（保留数据）。
  void goHome() {
    _screen = Screen.home;
    notifyListeners();
  }

  // ---------------- 成就 ----------------

  /// 导入成就（返回错误信息；null 表示成功）。
  String? importAchievement({required String name, required String csv}) {
    final err = Achievement.validateSize(csv);
    if (err != null) return err;
    _achievements.add(Achievement(
      id: IdGen.next(),
      name: name,
      csv: csv,
      importedAt: DateTime.now(),
    ));
    // 首次导入自动设为当前奖杯
    _activeAchievementId ??= _achievements.last.id;
    notifyListeners();
    unawaited(_persistAchievements());
    return null;
  }

  /// 设为当前奖杯图案。
  void setActiveAchievement(String? id) {
    _activeAchievementId = id;
    notifyListeners();
    unawaited(_storage.saveActiveAchievementId(id));
  }

  /// 删除成就；若删的是当前奖杯则回退到内置奖杯。
  Future<void> deleteAchievement(String id) async {
    _achievements.removeWhere((a) => a.id == id);
    if (_activeAchievementId == id) {
      _activeAchievementId = null;
    }
    // 从收藏中同步移除
    _collectedIds.remove(id);
    notifyListeners();
    await _persistAchievements();
    await _persistCollected();
  }

  // ---------------- 收藏品 ----------------

  /// 添加收藏品（最多 5 个）。返回错误信息，null 表示成功。
  String? addToCollection(String achievementId) {
    if (isCollected(achievementId)) {
      return '该成就已在收藏中';
    }
    if (isCollectionFull) {
      return '收藏品最多 5 个，请先移除一个';
    }
    _collectedIds.add(achievementId);
    notifyListeners();
    unawaited(_persistCollected());
    return null;
  }

  /// 移除收藏品。
  Future<void> removeFromCollection(String achievementId) async {
    _collectedIds.remove(achievementId);
    notifyListeners();
    await _persistCollected();
  }

  // ---------------- 主题 ----------------

  /// 切换白天/夜晚主题。
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    unawaited(_storage.saveThemeMode(
        mode == ThemeMode.dark ? 'dark' : 'light'));
  }

  /// 切换主题（白天 ↔ 夜晚）。
  void toggleTheme() {
    setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  // ---------------- 统计 ----------------

  /// 当前激活计划的统计。
  ProgressSummary get summary {
    final plan = activePlan;
    if (plan == null) return ProgressSummary.compute(const []);
    return ProgressSummary.compute(plan.items);
  }

  // ---------------- 持久化 ----------------

  Future<void> _persistPlans() => _storage.savePlans(_plans);

  Future<void> _persistSession() async {
    final s = _session;
    if (s != null) {
      await _storage.saveSession(s);
    } else {
      await _storage.clearSession();
    }
  }

  Future<void> _persistAchievements() =>
      _storage.saveAchievements(_achievements);

  Future<void> _persistCollected() =>
      _storage.saveCollectedAchievementIds(_collectedIds);

  Future<void> _persistActive() => _storage.saveActivePlanId(_activePlanId);

  Future<void> _persistAll() async {
    // 计划（含每条目的回答状态）与会话进度都要保存，
    // 否则重启后回答结果会丢失。
    await _persistPlans();
    await _persistSession();
    await _persistActive();
  }

  /// 清空全部数据。
  Future<void> clearAll() async {
    _plans = [];
    _achievements = [];
    _activePlanId = null;
    _activeAchievementId = null;
    _collectedIds = [];
    _session = null;
    _screen = Screen.home;
    notifyListeners();
    await _storage.clearAll();
  }
}

/// 顶层页面模式。
enum Screen { home, question, result }

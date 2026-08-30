import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/checklist.dart';
import '../models/question_session.dart';

/// 本地持久化（shared_preferences）。
///
/// 数据保存在手机本地，关闭 APP 再打开后：
/// 计划列表、回答结果、完成度、成就库都还在。
class AppStorage {
  static const _kPlans = 'plans_v1';
  static const _kActivePlanId = 'active_plan_id_v1';
  static const _kSession = 'session_v1';
  static const _kAchievements = 'achievements_v1';
  static const _kActiveAchievementId = 'active_achievement_id_v1';
  static const _kCollectedIds = 'collected_achievement_ids_v1';
  static const _kThemeMode = 'theme_mode_v1';

  // 旧版单清单 key（迁移用）
  static const _kLegacyChecklist = 'checklist_v1';

  // ---------------- 计划 ----------------

  Future<List<Checklist>> loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPlans);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        return list
            .map((e) => Checklist.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // 损坏则忽略
      }
    }
    // 旧版本数据迁移：单个清单 → 计划列表
    final legacy = prefs.getString(_kLegacyChecklist);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        final map = jsonDecode(legacy) as Map<String, dynamic>;
        return [Checklist.fromJson(map)];
      } catch (_) {
        // 忽略损坏数据
      }
    }
    return [];
  }

  Future<void> savePlans(List<Checklist> plans) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kPlans, jsonEncode(plans.map((e) => e.toJson()).toList()));
    // 迁移完成后清除旧 key
    await prefs.remove(_kLegacyChecklist);
  }

  Future<String?> loadActivePlanId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActivePlanId);
  }

  Future<void> saveActivePlanId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_kActivePlanId);
    } else {
      await prefs.setString(_kActivePlanId, id);
    }
  }

  // ---------------- 会话 ----------------

  Future<QuestionSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return QuestionSession.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(QuestionSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSession, jsonEncode(session.toJson()));
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSession);
  }

  // ---------------- 成就 ----------------

  Future<List<Achievement>> loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAchievements);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAchievements(List<Achievement> achievements) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAchievements,
        jsonEncode(achievements.map((e) => e.toJson()).toList()));
  }

  Future<String?> loadActiveAchievementId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveAchievementId);
  }

  Future<void> saveActiveAchievementId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_kActiveAchievementId);
    } else {
      await prefs.setString(_kActiveAchievementId, id);
    }
  }

  // ---------------- 收藏品 ----------------

  /// 收藏品：成就 id 列表（最多 5 个，保持添加顺序）。
  Future<List<String>> loadCollectedAchievementIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCollectedIds);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCollectedAchievementIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCollectedIds, jsonEncode(ids));
  }

  // ---------------- 主题 ----------------

  /// 主题：'light' 或 'dark'；null 表示跟随系统。
  Future<String?> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kThemeMode);
  }

  Future<void> saveThemeMode(String? mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (mode == null) {
      await prefs.remove(_kThemeMode);
    } else {
      await prefs.setString(_kThemeMode, mode);
    }
  }

  // ---------------- 清空 ----------------

  /// 清空全部数据（含旧版 key）。
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPlans);
    await prefs.remove(_kActivePlanId);
    await prefs.remove(_kSession);
    await prefs.remove(_kAchievements);
    await prefs.remove(_kActiveAchievementId);
    await prefs.remove(_kCollectedIds);
    await prefs.remove(_kThemeMode);
    await prefs.remove(_kLegacyChecklist);
  }
}

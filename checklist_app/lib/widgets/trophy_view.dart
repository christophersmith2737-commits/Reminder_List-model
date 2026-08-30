import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'trophy_pattern.dart';

/// 奖杯像素视图。
///
/// 两种用法：
/// - 追问页：[litFraction] 固定 0，整体半透明剪影 + 下方百分数
/// - 结果页：通过 [litFraction] 动画从 0→完成度，逐行点亮；
///   未点亮格子保持半透明（[dimOpacity]），点亮格子完全不透明
class TrophyView extends StatelessWidget {
  const TrophyView({
    super.key,
    required this.pattern,
    required this.litFraction,
    this.dimOpacity = 0.5,
    this.showPercent = true,
    this.percent,
    this.size = const Size(180, 216),
    this.cellGap = 0.5,
  });

  final TrophyPattern pattern;

  /// 0~1：已点亮比例（行优先从上到下）。
  final double litFraction;

  /// 未点亮格子的不透明度（默认 50%）。
  final double dimOpacity;

  /// 是否在奖杯下方显示百分数。
  final bool showPercent;

  /// 百分数数值（0~100）；为 null 时按 litFraction 计算。
  final int? percent;

  final Size size;

  /// 格子间隙（视觉上像拼豆之间的缝）。
  final double cellGap;

  @override
  Widget build(BuildContext context) {
    final pct = percent ?? (litFraction * 100).round();
    // 全部点亮（100%）后去掉格子缝隙，呈现完整图案
    final effectiveGap = litFraction >= 1.0 ? 0.0 : cellGap;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          // 按图案行列比例缩放，保证格子是正方形、图案不变形
          size: _fitSize(pattern, size),
          painter: _TrophyPainter(
            pattern: pattern,
            litFraction: litFraction,
            dimOpacity: dimOpacity,
            cellGap: effectiveGap,
          ),
        ),
        if (showPercent) ...[
          const SizedBox(height: 8),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: math.max(20, size.width / 6),
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }

  /// 在 [maxSize] 范围内按图案宽高比（cols:rows）计算实际显示尺寸。
  static Size _fitSize(TrophyPattern pattern, Size maxSize) {
    final aspect = pattern.cols / pattern.rows; // 宽 / 高
    if (maxSize.width / maxSize.height > aspect) {
      // 画布更宽 → 以高度为准
      return Size(maxSize.height * aspect, maxSize.height);
    }
    // 画布更高或相等 → 以宽度为准
    return Size(maxSize.width, maxSize.width / aspect);
  }
}

/// 结果页专用：奖杯从 0 开始逐行点亮到 [targetPercent]，
/// 动画约 [duration]，未点亮部分保持半透明剪影。
class TrophyReveal extends StatefulWidget {
  const TrophyReveal({
    super.key,
    required this.pattern,
    required this.targetPercent,
    this.duration = const Duration(seconds: 2),
    this.size = const Size(220, 264),
  });

  final TrophyPattern pattern;

  /// 最终完成度 0~100（点亮比例上限）。
  final int targetPercent;

  final Duration duration;
  final Size size;

  @override
  State<TrophyReveal> createState() => _TrophyRevealState();
}

class _TrophyRevealState extends State<TrophyReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.targetPercent.clamp(0, 100) / 100.0;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final lit = _t.value * target;
        return TrophyView(
          pattern: widget.pattern,
          litFraction: lit,
          showPercent: true,
          percent: (lit * 100).round(),
          size: widget.size,
        );
      },
    );
  }
}

class _TrophyPainter extends CustomPainter {
  _TrophyPainter({
    required this.pattern,
    required this.litFraction,
    required this.dimOpacity,
    required this.cellGap,
  }) : litCount = pattern.litPixels(litFraction);

  final TrophyPattern pattern;
  final double litFraction;
  final double dimOpacity;
  final double cellGap;
  final int litCount;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = pattern.cols;
    final rows = pattern.rows;
    final cellW = (size.width - cellGap * (cols - 1)) / cols;
    final cellH = (size.height - cellGap * (rows - 1)) / rows;
    // 强制正方形格子，并居中绘制（防止任何比例偏差导致变形）
    final cell = math.min(cellW, cellH);
    final contentW = cell * cols + cellGap * (cols - 1);
    final contentH = cell * rows + cellGap * (rows - 1);
    final offsetX = (size.width - contentW) / 2;
    final offsetY = (size.height - contentH) / 2;

    final litPaint = Paint();
    final dimPaint = Paint();

    for (var r = 0; r < rows; r++) {
      final row = pattern.grid[r];
      final y = offsetY + r * (cell + cellGap);
      for (var c = 0; c < cols; c++) {
        final color = row[c];
        if (color == null) continue; // 透明背景
        final x = offsetX + c * (cell + cellGap);
        final rect = Rect.fromLTWH(x, y, cell, cell);
        final lit = pattern.isLit(r, c, litCount);
        if (lit) {
          litPaint.color = color;
          canvas.drawRect(rect, litPaint);
        } else {
          dimPaint.color = color.withValues(alpha: dimOpacity);
          canvas.drawRect(rect, dimPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TrophyPainter oldDelegate) =>
      oldDelegate.litFraction != litFraction ||
      oldDelegate.dimOpacity != dimOpacity ||
      oldDelegate.litCount != litCount ||
      oldDelegate.cellGap != cellGap ||
      oldDelegate.pattern != pattern;
}

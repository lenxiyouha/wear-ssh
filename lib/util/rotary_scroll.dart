import 'package:flutter/material.dart';

/// 表冠滚动分发器。
///
/// 屏幕在 initState 里 attach 自己的主滚动控制器，dispose 时 detach。
/// 表冠产生的增量会驱动当前附着的列表平滑滚动。
class RotaryScroll {
  static ScrollController? _active;

  /// 每格表冠对应的逻辑像素
  static const double _pixelsPerDetent = 56;

  static void attach(ScrollController controller) {
    _active = controller;
  }

  static void detach(ScrollController controller) {
    if (identical(_active, controller)) _active = null;
  }

  static void handle(double delta) {
    final controller = _active;
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    final target = (position.pixels + delta * _pixelsPerDetent)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < 0.5) return;
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }
}

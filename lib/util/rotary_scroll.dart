import 'package:flutter/material.dart';

/// 表冠滚动分发器。
///
/// 采用控制器栈：页面 push 时 attach 自己的主滚动控制器，pop 时 detach。
/// 栈顶始终是当前最上层页面的列表，表冠事件只驱动它；
/// 子页面 pop 后，下层页面的控制器自动恢复为栈顶。
class RotaryScroll {
  static final List<ScrollController> _stack = [];

  /// 每格表冠对应的逻辑像素
  static const double _pixelsPerDetent = 56;

  static void attach(ScrollController controller) {
    _stack.remove(controller);
    _stack.add(controller);
  }

  static void detach(ScrollController controller) {
    _stack.remove(controller);
  }

  static void handle(double delta) {
    if (_stack.isEmpty) return;
    final controller = _stack.last;
    if (!controller.hasClients) return;
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

import 'package:flutter/services.dart';

/// 与原生 Wear OS 层的通信：
///  - 旋转表冠 (rotary encoder) 滚动事件
///  - 连接期间保持屏幕常亮
class WearBridge {
  static const MethodChannel _channel = MethodChannel('dev.wearssh.app/wear');

  /// 表冠旋转回调，参数为增量（正 = 向前滚动）
  static void Function(double delta)? onRotary;

  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'rotary') {
        final delta = (call.arguments as num?)?.toDouble() ?? 0;
        if (delta != 0) onRotary?.call(delta);
      }
      return null;
    });
  }

  /// 连接期间保持屏幕常亮，避免息屏导致会话中断
  static Future<void> keepScreenOn(bool on) async {
    try {
      await _channel.invokeMethod('keepScreenOn', {'on': on});
    } on PlatformException {
      // 忽略：非 Wear 设备或原生层不可用
    } on MissingPluginException {
      // 忽略
    }
  }
}

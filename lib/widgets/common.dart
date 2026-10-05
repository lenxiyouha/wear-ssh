import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// 圆表顶部标题区：标题居中，两侧可放返回/操作按钮
class WatchHeader extends StatelessWidget {
  const WatchHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: subtitle == null ? 42 : 52,
      child: Stack(
        children: [
          if (leading != null || onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: leading ??
                  _RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: onBack,
                  ),
            ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}

/// 小型圆形图标按钮（返回/刷新等）
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap, this.color});

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.text;
    return Material(
      color: const Color(0xFF131C2E),
      shape: const CircleBorder(side: BorderSide(color: AppColors.stroke)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: fg),
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => _RoundIconButton(
        icon: icon,
        onTap: onTap,
        color: color,
      );
}

/// 胶囊按钮
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.filled = true,
    this.danger = false,
    this.dense = false,
    this.expanded = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final bool danger;
  final bool dense;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? (danger ? Colors.white : AppColors.onPrimary) : AppColors.text;
    final bg = filled ? (danger ? AppColors.danger : AppColors.primary) : Colors.transparent;
    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: dense ? 13 : 15, color: fg),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: dense ? 11.5 : 12.5,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    );
    return Material(
      color: bg,
      shape: StadiumBorder(
        side: BorderSide(
          color: filled ? Colors.transparent : AppColors.stroke,
          width: 1.1,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 11 : 16,
            vertical: dense ? 7 : 9,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 分区卡片
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child, this.accent});

  final String? title;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  if (accent != null)
                    Container(
                      width: 3,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  if (accent != null) const SizedBox(width: 5),
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: accent ?? AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// 键值行
class KVRow extends StatelessWidget {
  const KVRow({super.key, required this.k, required this.v, this.vColor});

  final String k;
  final String v;
  final Color? vColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: vColor ?? AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 空状态提示
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: const Color(0xFF33415C)),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

/// 列表上下渐隐遮罩（圆表上提示还有更多内容）
class EdgeFades extends StatelessWidget {
  const EdgeFades({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.bg, Color(0x0005080F)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [AppColors.bg, Color(0x0005080F)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 统一样式的应用对话框
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required Widget title,
  required Widget content,
  List<Widget>? actions,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF101A2C),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.all(16),
      titlePadding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      actionsPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      actionsAlignment: MainAxisAlignment.center,
      title: DefaultTextStyle(
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        child: title,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 11.5, color: AppColors.textDim),
          child: content,
        ),
      ),
      actions: actions,
    ),
  );
}

/// 轻提示
void showToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(message, textAlign: TextAlign.center),
      ),
    );
}

// ---------------------------------------------------------------- 传输进度

/// 一次上传/下载的进度控制器
class TransferController extends ChangeNotifier {
  TransferController({required this.title});

  final String title;

  double? fraction;
  int bytes = 0;
  int? total;
  String phase = '准备中 …';
  bool cancelled = false;
  bool _finished = false;

  final Completer<void> _done = Completer<void>();

  Future<void> get finished => _done.future;

  void update({double? fraction, int? bytes, int? total, String? phase}) {
    if (this.total != total) this.total = total;
    if (bytes != null) this.bytes = bytes;
    if (fraction != null) this.fraction = fraction;
    if (phase != null) this.phase = phase;
    notifyListeners();
  }

  void cancel() {
    cancelled = true;
    notifyListeners();
  }

  void markFinished() {
    if (_finished) return;
    _finished = true;
    if (!_done.isCompleted) _done.complete();
    notifyListeners();
  }
}

/// 全屏传输进度对话框，直到 [controller].markFinished 才关闭
Future<void> showTransferProgress(
  BuildContext context,
  TransferController controller,
) async {
  final nav = Navigator.of(context);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferDialog(controller: controller),
    ),
  );
  await controller.finished;
  try {
    nav.pop();
  } catch (_) {}
}

class _TransferDialog extends StatelessWidget {
  const _TransferDialog({required this.controller});

  final TransferController controller;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFF101A2C),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: const EdgeInsets.all(18),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        actionsPadding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        actionsAlignment: MainAxisAlignment.center,
        content: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final pct = controller.fraction;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          value: pct,
                          strokeWidth: 5,
                          backgroundColor: const Color(0xFF1D2A42),
                        ),
                      ),
                      Text(
                        pct == null
                            ? '…'
                            : '${(pct * 100).clamp(0, 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  controller.phase,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          PillButton(
            label: '取消',
            filled: false,
            dense: true,
            danger: true,
            onPressed: controller.cancel,
          ),
        ],
      ),
    );
  }
}

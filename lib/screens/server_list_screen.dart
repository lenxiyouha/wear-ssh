import 'package:flutter/material.dart';

import '../app_nav.dart';
import '../models/server_config.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../util/rotary_scroll.dart';
import '../widgets/common.dart';
import 'server_edit_screen.dart';
import 'session_screen.dart';

/// 首页：已保存的服务器列表
class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    RotaryScroll.attach(_scroll);
  }

  @override
  void dispose() {
    RotaryScroll.detach(_scroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final servers = model.servers;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Column(
            children: [
              WatchHeader(
                title: '圆表SSH',
                subtitle: servers.isEmpty ? null : '${servers.length} 台服务器',
              ),
              Expanded(
                child: servers.isEmpty
                    ? const EmptyHint(
                        icon: Icons.dns_outlined,
                        text: '还没有服务器\n点击下方按钮添加一台',
                      )
                    : EdgeFades(
                        child: ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.only(top: 2, bottom: 6),
                          children: [
                            for (final cfg in servers)
                              _ServerCard(
                                config: cfg,
                                active:
                                    model.connection?.config.id == cfg.id,
                                onTap: () => _connectFlow(cfg),
                                onLongPress: () => _options(cfg),
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PillButton(
                    label: '添加服务器',
                    icon: Icons.add_rounded,
                    dense: true,
                    onPressed: () => _openEditor(null),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(ServerConfig? config) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServerEditScreen(existing: config)),
    );
  }

  /// 长按卡片：编辑 / 删除 / 重置指纹
  Future<void> _options(ServerConfig config) async {
    final model = AppScope.of(context);
    await showAppDialog<void>(
      context: context,
      title: Text(config.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DialogAction(
            icon: Icons.edit_rounded,
            label: '编辑服务器',
            onTap: () {
              Navigator.of(context).pop();
              _openEditor(config);
            },
          ),
          if (config.hostKeyFingerprint != null)
            _DialogAction(
              icon: Icons.shield_outlined,
              label: '重置已信任的指纹',
              onTap: () async {
                Navigator.of(context).pop();
                config.hostKeyFingerprint = null;
                await model.saveServer(config);
                if (mounted) showToast(context, '已重置指纹，下次连接将重新确认');
              },
            ),
          _DialogAction(
            icon: Icons.delete_outline_rounded,
            label: '删除服务器',
            danger: true,
            onTap: () async {
              Navigator.of(context).pop();
              final ok = await showAppDialog<bool>(
                context: context,
                title: const Text('确认删除？'),
                content: Text('将从本机移除「${config.name}」及其保存的凭据。'),
                actions: [
                  PillButton(
                    label: '取消',
                    filled: false,
                    dense: true,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  PillButton(
                    label: '删除',
                    dense: true,
                    danger: true,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              );
              if (ok == true) {
                await model.deleteServer(config.id);
                if (mounted) showToast(context, '已删除');
              }
            },
          ),
        ],
      ),
      actions: [
        PillButton(
          label: '关闭',
          filled: false,
          dense: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// 连接流程：进度对话框 →（可选）指纹确认 → 进入会话页
  Future<void> _connectFlow(ServerConfig config) async {
    final model = AppScope.of(context);
    if (model.connecting || model.connection != null) return;

    final phase = ValueNotifier<String>('准备连接 …');
    final rootNav = appNavigatorKey.currentState;

    _showConnectDialog(phase, model, config);

    try {
      await model.connect(
        config,
        onPhase: (p) => phase.value = p,
        verifyHostKey: (type, fingerprint) =>
            _confirmHostKey(type, fingerprint, config),
      );
      rootNav?.pop(); // 关闭进度对话框
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SessionScreen(configId: config.id)),
      );
    } on ConnectCancelled {
      rootNav?.pop();
    } catch (e) {
      rootNav?.pop();
      if (!mounted) return;
      await showAppDialog<void>(
        context: context,
        title: const Text('连接失败'),
        content: Text(
          friendlyError(e, config),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: AppColors.text),
        ),
        actions: [
          PillButton(
            label: '知道了',
            dense: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    } finally {
      phase.dispose();
    }
  }

  void _showConnectDialog(
    ValueNotifier<String> phase,
    AppModel model,
    ServerConfig config,
  ) {
    showDialog<void>(
      context: appNavigatorKey.currentContext ?? context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF101A2C),
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding: const EdgeInsets.all(18),
          contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          actionsPadding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          actionsAlignment: MainAxisAlignment.center,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 3.4),
              ),
              const SizedBox(height: 10),
              Text(
                config.name,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              ValueListenableBuilder<String>(
                valueListenable: phase,
                builder: (_, value, _) => Text(
                  value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            PillButton(
              label: '取消',
              filled: false,
              dense: true,
              danger: true,
              onPressed: model.cancelPendingConnect,
            ),
          ],
        ),
      ),
    );
  }

  /// 主机指纹确认（首次连接 / 指纹变化）
  Future<bool> _confirmHostKey(
    String type,
    String fingerprint,
    ServerConfig config,
  ) async {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return false;
    final mismatch = config.hostKeyFingerprint != null;
    final result = await showAppDialog<bool>(
      context: ctx,
      title: Text(mismatch ? '⚠ 指纹已变更！' : '确认主机密钥'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mismatch
                ? '该服务器此前的指纹与本次不符，可能正在遭受中间人攻击，请务必核对后再决定：'
                : '首次连接该服务器，请核对指纹是否与服务器端一致（ssh-keygen -lf /etc/ssh/ssh_host_*）：',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, height: 1.4),
          ),
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF070D18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: mismatch ? AppColors.danger : AppColors.stroke,
              ),
            ),
            child: SelectableText(
              fingerprint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('类型：$type', style: const TextStyle(fontSize: 10)),
        ],
      ),
      actions: [
        PillButton(
          label: '拒绝',
          filled: false,
          dense: true,
          danger: true,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        PillButton(
          label: '信任并连接',
          dense: true,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    );
    return result ?? false;
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.config,
    required this.active,
    required this.onTap,
    required this.onLongPress,
  });

  final ServerConfig config;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  Color get _avatarColor {
    final hues = [190, 150, 265, 30, 330, 45, 210];
    final hue = hues[config.id.hashCode.abs() % hues.length].toDouble();
    return HSLColor.fromAHSL(1, hue, .55, .32).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final initial = config.name.isEmpty
        ? '?'
        : config.name.trim().substring(0, 1).toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: active ? AppColors.ok : AppColors.stroke,
            width: active ? 1.2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: _avatarColor,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              config.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? AppColors.ok
                                  : const Color(0xFF31405C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${config.login}:${config.port}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.text;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

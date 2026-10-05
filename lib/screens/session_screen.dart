import 'package:flutter/material.dart';

import '../state/app_model.dart';
import '../theme.dart';
import '../util/rotary_scroll.dart';
import '../widgets/common.dart';
import 'file_browser_screen.dart';
import 'server_edit_screen.dart';
import 'server_info_screen.dart';
import 'terminal_screen.dart';

/// 连接成功后的功能中枢：信息 / 文件 / 终端
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.configId});

  final String configId;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final ScrollController _scroll = ScrollController();
  bool _working = false;

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
    final conn = model.connection;

    // 连接已断开：提示并等待返回
    if (conn == null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Column(
              children: [
                const WatchHeader(title: '连接已断开'),
                const Expanded(
                  child: EmptyHint(
                    icon: Icons.wifi_off_rounded,
                    text: '与服务器的连接已断开\n可能已超时或被服务端关闭',
                  ),
                ),
                PillButton(
                  label: '返回列表',
                  dense: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    }

    final config = conn.config;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          // 离开即断开，省电且避免会话残留
          // ignore: discarded_futures
          model.disconnect();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Column(
              children: [
                WatchHeader(
                  title: config.name,
                  subtitle: '已连接 · ${conn.remoteVersion}',
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2A22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.ok),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 12, color: AppColors.ok),
                      const SizedBox(width: 5),
                      Text(
                        '${config.login}:${config.port}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.ok,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: EdgeFades(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      children: [
                        _MenuTile(
                          icon: Icons.monitor_heart_outlined,
                          color: AppColors.primary,
                          title: '服务器信息',
                          subtitle: '系统 / 硬件 / 运行状态',
                          onTap: () => _push(const ServerInfoScreen()),
                        ),
                        _MenuTile(
                          icon: Icons.folder_open_rounded,
                          color: AppColors.warn,
                          title: '文件管理',
                          subtitle: '浏览 · 上传 · 下载',
                          onTap: () => _push(const FileBrowserScreen()),
                        ),
                        _MenuTile(
                          icon: Icons.terminal_rounded,
                          color: AppColors.ok,
                          title: '终端',
                          subtitle: '执行远程命令',
                          onTap: () => _push(const TerminalScreen()),
                        ),
                        _MenuTile(
                          icon: Icons.settings_outlined,
                          color: AppColors.textDim,
                          title: '编辑服务器',
                          subtitle: '修改连接配置',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ServerEditScreen(existing: config),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                PillButton(
                  label: _working ? '正在断开 …' : '断开连接',
                  icon: Icons.power_settings_new_rounded,
                  dense: true,
                  danger: true,
                  filled: false,
                  onPressed: _working ? null : _disconnect,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _disconnect() async {
    setState(() => _working = true);
    // ignore: discarded_futures
    AppScope.of(context).disconnect();
    if (mounted) Navigator.of(context).pop();
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.stroke),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
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

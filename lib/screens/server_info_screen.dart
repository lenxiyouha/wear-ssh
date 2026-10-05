import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/server_config.dart';
import '../ssh/host_info.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../util/rotary_scroll.dart';
import '../widgets/common.dart';

/// 服务器信息：连接详情 + 实时系统状态
class ServerInfoScreen extends StatefulWidget {
  const ServerInfoScreen({super.key});

  @override
  State<ServerInfoScreen> createState() => _ServerInfoScreenState();
}

class _ServerInfoScreenState extends State<ServerInfoScreen> {
  final ScrollController _scroll = ScrollController();
  HostInfo? _info;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    RotaryScroll.attach(_scroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    RotaryScroll.detach(_scroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final conn = AppScope.of(context).connection;
    if (conn == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await HostInfo.fetch(
        conn.client,
        remoteVersion: conn.remoteVersion,
      );
      if (!mounted) return;
      setState(() {
        _info = info;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '获取信息失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final conn = model.connection;

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
                    text: '连接已断开，无法读取服务器信息',
                  ),
                ),
                PillButton(
                  label: '返回',
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
    final info = _info;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Column(
            children: [
              WatchHeader(
                title: '服务器信息',
                subtitle: config.name,
                onBack: () => Navigator.of(context).pop(),
                trailing: RoundIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: _loading ? null : _load,
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      )
                    : EdgeFades(
                        child: ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.only(top: 2, bottom: 8),
                          children: [
                            if (_error != null)
                              SectionCard(
                                title: '错误',
                                accent: AppColors.danger,
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                            SectionCard(
                              title: '连接',
                              accent: AppColors.primary,
                              child: Column(
                                children: [
                                  KVRow(k: '地址', v: config.address),
                                  KVRow(k: '登录用户', v: config.username),
                                  KVRow(
                                    k: '认证方式',
                                    v: config.authMethod ==
                                            AuthMethod.password
                                        ? '密码'
                                        : 'SSH 私钥',
                                  ),
                                  KVRow(
                                    k: '服务端',
                                    v: conn.remoteVersion,
                                  ),
                                  KVRow(
                                    k: '响应时间',
                                    v: info == null || info.latencyMs < 0
                                        ? '—'
                                        : '${info.latencyMs} ms',
                                    vColor: (info != null &&
                                            info.latencyMs >= 0 &&
                                            info.latencyMs < 300)
                                        ? AppColors.ok
                                        : null,
                                  ),
                                  KVRow(
                                    k: '建立时间',
                                    v: _fmtConnected(conn.connectedAt),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () async {
                                      final fp = config.hostKeyFingerprint;
                                      if (fp == null) return;
                                      await Clipboard.setData(
                                        ClipboardData(text: fp),
                                      );
                                      if (context.mounted) {
                                        showToast(context, '指纹已复制');
                                      }
                                    },
                                    child: KVRow(
                                      k: '主机指纹',
                                      v: config.hostKeyFingerprint == null
                                          ? '未记录'
                                          : 'SHA256…（点按复制）',
                                      vColor: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (info != null) ...[
                              SectionCard(
                                title: '系统',
                                accent: AppColors.ok,
                                child: Column(
                                  children: [
                                    KVRow(k: '操作系统', v: info.os),
                                    KVRow(k: '内核', v: info.kernel),
                                    KVRow(k: '主机名', v: info.hostname),
                                    KVRow(k: '当前用户', v: info.user),
                                    KVRow(k: '局域网 IP', v: info.lanIp),
                                    KVRow(
                                      k: '采集时间',
                                      v: _fmtTime(info.fetchedAt),
                                    ),
                                  ],
                                ),
                              ),
                              SectionCard(
                                title: '运行状态',
                                accent: AppColors.warn,
                                child: Column(
                                  children: [
                                    KVRow(
                                      k: 'CPU',
                                      v:
                                          '${info.cpuModel} · ${info.cpuCores}',
                                    ),
                                    KVRow(k: '内存', v: info.memory),
                                    KVRow(k: '根分区', v: info.disk),
                                    KVRow(
                                      k: '运行时长',
                                      v: info.uptime.length > 46
                                          ? '${info.uptime.substring(0, 46)}…'
                                          : info.uptime,
                                    ),
                                  ],
                                ),
                              ),
                            ] else
                              const SectionCard(
                                title: '系统',
                                accent: AppColors.ok,
                                child: Text(
                                  '暂无数据，点右上角刷新',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textDim,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              PillButton(
                label: _loading ? '采集中 …' : '刷新数据',
                icon: Icons.sync_rounded,
                dense: true,
                filled: false,
                onPressed: _loading ? null : _load,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtConnected(DateTime t) {
    final local = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _fmtTime(DateTime t) => _fmtConnected(t);
}

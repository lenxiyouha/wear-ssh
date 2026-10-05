import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_config.dart';
import '../util/wear_bridge.dart';
import '../ssh/errors.dart';

export '../ssh/errors.dart';

/// 通过 InheritedNotifier 向整棵树暴露 [AppModel]
class AppScope extends InheritedNotifier<AppModel> {
  const AppScope({super.key, required AppModel model, required super.child})
      : super(notifier: model);

  /// 读取模型（在 build 中调用，会自动订阅更新）
  static AppModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 未挂载在 Widget 树上');
    return scope!.notifier!;
  }
}

/// 一条活动的 SSH 连接（含缓存的 SFTP 会话）
class SshConnection {
  SshConnection({
    required this.config,
    required this.client,
    required this.connectedAt,
  });

  final ServerConfig config;
  final SSHClient client;
  final DateTime connectedAt;

  SftpClient? _sftp;

  bool get isClosed => client.isClosed;

  String get remoteVersion => client.remoteVersion ?? '未知';

  /// 获取（或建立）共享的 SFTP 会话
  Future<SftpClient> sftp() async {
    if (isClosed) throw ConnectionClosed();
    return _sftp ??= await client.sftp();
  }

  void invalidateSftp() {
    _sftp = null;
  }

  Future<void> close() async {
    try {
      await _sftp?.close();
    } catch (_) {}
    _sftp = null;
    try {
      await client.close();
    } catch (_) {}
  }
}

/// 全局应用状态：服务器列表 + 活动连接
class AppModel extends ChangeNotifier {
  SharedPreferences? _prefs;
  List<ServerConfig> servers = [];
  bool loaded = false;
  SshConnection? connection;

  int _connectSeq = 0;

  static const String _kServers = 'servers_v1';

  // ---------------------------------------------------------------- 存储

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_kServers);
    if (raw != null) {
      try {
        servers = ServerConfig.decodeList(raw);
      } catch (_) {
        servers = [];
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _prefs?.setString(_kServers, ServerConfig.encodeList(servers));
    } catch (_) {}
  }

  Future<void> saveServer(ServerConfig config) async {
    final idx = servers.indexWhere((s) => s.id == config.id);
    if (idx >= 0) {
      servers[idx] = config;
    } else {
      servers.add(config);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deleteServer(String id) async {
    servers.removeWhere((s) => s.id == id);
    await _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------- 连接

  bool get connecting => _connecting;
  bool _connecting = false;

  /// 建立连接。
  ///
  /// [verifyHostKey] 在首次（或指纹变化时）收到主机密钥，返回是否信任。
  /// [onPhase] 用于把进度阶段回显到连接对话框。
  Future<void> connect(
    ServerConfig config, {
    required Future<bool> Function(String type, String fingerprint)
        verifyHostKey,
    required void Function(String phase) onPhase,
  }) async {
    if (connection != null) await disconnect();
    final seq = ++_connectSeq;
    _connecting = true;

    void check() {
      if (seq != _connectSeq) throw ConnectCancelled();
    }

    SSHSocket? socket;
    try {
      onPhase('连接 ${config.address} …');
      socket = await SSHSocket.connect(
        config.host,
        config.port,
        timeout: const Duration(seconds: 15),
      );
      check();

      List<SSHIdentity>? identities;
      if (config.authMethod == AuthMethod.privateKey) {
        onPhase('解析私钥 …');
        final pem = config.privateKeyPem.trim();
        if (pem.isEmpty) {
          throw const SshConfigError('未填写私钥内容');
        }
        identities = SSHKeyPair.fromPem(
          pem,
          config.keyPassphrase.isEmpty ? null : config.keyPassphrase,
        );
        check();
      }

      onPhase('协商加密通道 …');
      final client = SSHClient(
        socket,
        username: config.username,
        identities: identities,
        onPasswordRequest: () {
          onPhase('校验密码 …');
          if (config.password.isEmpty) return null;
          return config.password;
        },
        onVerifyHostKey: (type, fingerprint) async {
          final fp = utf8.decode(fingerprint, allowMalformed: true);
          final saved = config.hostKeyFingerprint;
          if (saved != null && saved == fp) return true;
          final trusted = await verifyHostKey(type, fp);
          if (trusted) {
            config.hostKeyFingerprint = fp;
            await _persist();
          }
          return trusted;
        },
        keepAliveInterval: const Duration(seconds: 10),
        handshakeTimeout: const Duration(seconds: 15),
        authTimeout: const Duration(seconds: 20),
      );

      onPhase('身份认证 …');
      await client.authenticated;
      check();

      config.lastConnectedMs = DateTime.now().millisecondsSinceEpoch;
      await _persist();

      final conn = SshConnection(
        config: config,
        client: client,
        connectedAt: DateTime.now(),
      );
      connection = conn;

      // 远端断线监听：掉线时清空连接并通知界面
      unawaited(client.done.whenComplete(() {
        if (identical(connection, conn)) {
          conn.invalidateSftp();
          connection = null;
          unawaited(WearBridge.keepScreenOn(false));
          notifyListeners();
        }
      }));

      await WearBridge.keepScreenOn(true);
      notifyListeners();
    } on ConnectCancelled {
      _connecting = false;
      try {
        await socket?.close();
      } catch (_) {}
      rethrow;
    } catch (e) {
      _connecting = false;
      try {
        await socket?.close();
      } catch (_) {}
      rethrow;
    } finally {
      if (seq == _connectSeq) _connecting = false;
    }
  }

  /// 取消正在进行、尚未完成的连接尝试
  void cancelPendingConnect() => ++_connectSeq;

  Future<void> disconnect() async {
    ++_connectSeq; // 使进行中的连接作废
    final conn = connection;
    connection = null;
    _connecting = false;
    unawaited(WearBridge.keepScreenOn(false));
    notifyListeners();
    if (conn != null) await conn.close();
  }
}

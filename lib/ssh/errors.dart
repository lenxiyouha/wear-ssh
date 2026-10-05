import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../models/server_config.dart';

/// 用户主动取消连接
class ConnectCancelled implements Exception {
  @override
  String toString() => '已取消连接';
}

/// 配置类错误（私钥为空等），message 直接面向用户
class SshConfigError implements Exception {
  const SshConfigError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 连接已关闭时继续操作
class ConnectionClosed implements Exception {
  @override
  String toString() => '连接已断开';
}

/// 把底层异常翻译成表上可读的中文提示
String friendlyError(Object e, ServerConfig config) {
  if (e is ConnectCancelled) return '已取消连接';
  if (e is SshConfigError || e is ConnectionClosed) return e.toString();
  if (e is SocketException) {
    return '无法连接 ${config.address}\n请检查网络与端口是否可达';
  }
  if (e is TimeoutException) {
    return '连接 ${config.address} 超时';
  }
  if (e is SSHHandshakeError) {
    return 'SSH 握手失败\n${config.address} 可能不是 SSH 服务';
  }
  if (e is SSHAuthFailError) {
    return '认证失败：用户名或密码/密钥不正确';
  }
  if (e is SSHAuthError) {
    return '认证未通过，请检查凭据配置';
  }
  if (e is SSHKeyDecodeError) {
    return '私钥解析失败：请检查密钥格式（支持 OpenSSH/PEM）';
  }
  if (e is SSHKeyDecryptError) {
    return '私钥口令错误，无法解密密钥';
  }
  if (e is SSHHostkeyError) {
    return '主机密钥校验未通过，已取消连接';
  }
  if (e is SSHSocketError || e is SSHDisconnectError) {
    return '连接被服务器关闭';
  }
  if (e is SftpStatusError) {
    return 'SFTP 操作失败：$e';
  }
  if (e is FileSystemException) {
    return '本地文件访问失败：${e.message}';
  }
  final text = e.toString().trim();
  if (text.isEmpty) return '发生未知错误';
  return text.length > 160 ? '${text.substring(0, 160)}…' : text;
}

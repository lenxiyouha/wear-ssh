import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

/// 通过执行命令采集到的服务器信息
class HostInfo {
  const HostInfo({
    required this.os,
    required this.kernel,
    required this.hostname,
    required this.user,
    required this.cpuModel,
    required this.cpuCores,
    required this.memory,
    required this.disk,
    required this.uptime,
    required this.lanIp,
    required this.latencyMs,
    required this.remoteVersion,
    required this.fetchedAt,
  });

  final String os;
  final String kernel;
  final String hostname;
  final String user;
  final String cpuModel;
  final String cpuCores;
  final String memory;
  final String disk;
  final String uptime;
  final String lanIp;
  final int latencyMs;
  final String remoteVersion;
  final DateTime fetchedAt;

  static const String _na = '未知';

  /// 一次性并发执行一组探测命令
  static Future<HostInfo> fetch(
    SSHClient client, {
    String remoteVersion = '',
  }) async {
    Future<String> q(String cmd) async {
      try {
        final out = await client.run(cmd, runInPty: false);
        return utf8.decode(out, allowMalformed: true).trim();
      } catch (_) {
        return '';
      }
    }

    // 延迟测量：往返一次极小命令
    final sw = Stopwatch()..start();
    var latency = -1;
    try {
      await client.run('true', runInPty: false);
      latency = sw.elapsedMilliseconds;
    } catch (_) {}

    final results = await Future.wait<String>([
      // 操作系统
      q(r'''export LANG=C LC_ALL=C; if [ -f /etc/os-release ]; then . /etc/os-release; echo "${PRETTY_NAME:-Linux}"; else uname -s; fi'''),
      // 内核 / 架构
      q(r'''uname -srm'''),
      // 主机名
      q(r'''hostname 2>/dev/null || uname -n'''),
      // 当前用户
      q(r'''whoami'''),
      // 运行时长与负载
      q(r'''uptime'''),
      // CPU 核数
      q(r'''nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo'''),
      // CPU 型号
      q(r'''awk -F: '/model name|Processor|Hardware/{gsub(/^ +/,"",$2); if($2!=""){print $2; exit}}' /proc/cpuinfo 2>/dev/null'''),
      // 内存使用
      q(r'''free -m 2>/dev/null | awk '/^Mem:/{printf "%d/%d MB", $3, $2}' '''),
      // 根分区
      q(r'''df -h / 2>/dev/null | awk 'NR==2{print $3"/"$4" ("$5")"}' '''),
      // 局域网 IP
      q(r'''hostname -I 2>/dev/null | awk '{print $1}' '''),
    ]);

    String pick(String v, [String fallback = _na]) =>
        v.isEmpty ? fallback : v;

    return HostInfo(
      os: pick(results[0]),
      kernel: pick(results[1]),
      hostname: pick(results[2]),
      user: pick(results[3]),
      uptime: pick(results[4]),
      cpuCores: results[5].isEmpty ? _na : '${results[5]} 核',
      cpuModel: pick(results[6]),
      memory: pick(results[7]),
      disk: pick(results[8]),
      lanIp: pick(results[9], '—'),
      latencyMs: latency,
      remoteVersion: remoteVersion,
      fetchedAt: DateTime.now(),
    );
  }
}

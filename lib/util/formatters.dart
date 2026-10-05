/// 展示类格式化工具
library;

/// 字节数 → 人类可读
String formatBytes(num bytes) {
  if (bytes < 0) return '-';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  if (i == 0) return '${value.toInt()} ${units[i]}';
  final s = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$s ${units[i]}';
}

/// 时间戳 → `MM-DD HH:mm`
String formatTime(int? ms) {
  if (ms == null) return '从未连接';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

/// 毫秒 → 耗时描述
String formatLatency(int ms) => '$ms ms';

/// 路径压缩显示：`/var/www/api/uploads` → `…/www/api/uploads`
String compressPath(String path, {int maxLen = 24}) {
  if (path.length <= maxLen) return path;
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  for (var take = 1; take <= parts.length; take++) {
    final candidate = '/${parts.sublist(parts.length - take).join('/')}';
    if (candidate.length <= maxLen) {
      return take == parts.length ? candidate : '…$candidate';
    }
  }
  return '…${path.substring(path.length - maxLen + 1)}';
}

/// 中间省略的文件名显示
String ellipsize(String name, int maxChars) {
  if (name.length <= maxChars) return name;
  final keep = (maxChars - 1) ~/ 2;
  return '${name.substring(0, keep)}…${name.substring(name.length - keep)}';
}

/// 安全拼接远端路径
String joinRemote(String dir, String name) {
  if (dir.endsWith('/')) return '$dir$name';
  return '$dir/$name';
}

/// 取远端路径的父目录
String parentOf(String path) {
  if (path == '/' || path.isEmpty) return '/';
  var p = path;
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  final idx = p.lastIndexOf('/');
  if (idx <= 0) return '/';
  return p.substring(0, idx);
}

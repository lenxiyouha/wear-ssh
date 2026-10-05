import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../state/app_model.dart';
import '../theme.dart';
import '../util/formatters.dart';
import '../util/rotary_scroll.dart';
import '../widgets/common.dart';

/// SFTP 文件管理
class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({super.key});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FsEntry {
  _FsEntry({
    required this.name,
    required this.isDir,
    this.size,
    this.mtime,
    this.isLink = false,
  });

  final String name;
  final bool isDir;
  final int? size;
  final int? mtime;
  final bool isLink;
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  final ScrollController _scroll = ScrollController();

  String _cwd = '/';
  List<_FsEntry> _entries = [];
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

  AppModel get _model => AppScope.of(context);

  SshConnection get _conn => _model.connection!;

  /// 把异常转成用户可读文本（连接可能已断开）
  String _errText(Object e) {
    final cfg = _model.connection?.config;
    if (cfg == null) return '连接已断开';
    return friendlyError(e, cfg);
  }

  // ------------------------------------------------------------ 目录加载

  Future<void> _load() async {
    if (_model.connection == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sftp = await _conn.sftp();
      final names = await sftp.listdir(_cwd);
      final items = <_FsEntry>[];
      for (final n in names) {
        if (n.filename == '.' || n.filename == '..') continue;
        items.add(_FsEntry(
          name: n.filename,
          isDir: n.attr.type == SftpFileType.directory,
          isLink: n.attr.type == SftpFileType.symbolicLink,
          size: n.attr.size,
          mtime: n.attr.modifyTime,
        ));
      }
      items.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        _entries = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errText(e);
      });
    }
  }

  Future<void> _guard(Future<void> Function() action,
      {String? okMessage}) async {
    try {
      await action();
      if (okMessage != null && mounted) showToast(context, okMessage);
    } catch (e) {
      if (mounted) showToast(context, _errText(e));
    }
  }

  // ------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    if (_model.connection == null) {
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
                    text: '连接已断开，文件管理不可用',
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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Column(
            children: [
              WatchHeader(
                title: compressPath(_cwd),
                subtitle: _conn.config.name,
                onBack: () => Navigator.of(context).pop(),
                trailing: RoundIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: _loading ? null : _load,
                ),
              ),
              Expanded(
                child: _buildBody(),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PillButton(
                    label: '上传',
                    icon: Icons.upload_rounded,
                    dense: true,
                    onPressed: _uploadFlow,
                  ),
                  const SizedBox(width: 8),
                  PillButton(
                    label: '新建目录',
                    icon: Icons.create_new_folder_outlined,
                    dense: true,
                    filled: false,
                    onPressed: _newFolder,
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

  Widget _buildBody() {
    if (_loading && _entries.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }
    if (_error != null) {
      return EmptyHint(icon: Icons.error_outline_rounded, text: _error!);
    }
    if (_entries.isEmpty) {
      return const EmptyHint(icon: Icons.folder_open_rounded, text: '此目录为空');
    }

    return EdgeFades(
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.only(top: 2, bottom: 6),
        children: [
          if (_cwd != '/') _upTile(),
          for (final e in _entries) _entryTile(e),
          const SizedBox(height: 2),
          Center(
            child: Text(
              '${_entries.length} 个项目',
              style: const TextStyle(fontSize: 9.5, color: AppColors.textDim),
            ),
          ),
        ],
      ),
    );
  }

  Widget _upTile() {
    return _tile(
      icon: Icons.arrow_upward_rounded,
      color: AppColors.primary,
      name: '上级目录',
      trailing: null,
      onTap: () {
        setState(() => _cwd = parentOf(_cwd));
        _load();
      },
    );
  }

  Widget _entryTile(_FsEntry e) {
    return _tile(
      icon: e.isLink
          ? Icons.link_rounded
          : e.isDir
              ? Icons.folder_rounded
              : Icons.insert_drive_file_rounded,
      color: e.isLink
          ? AppColors.ok
          : e.isDir
              ? AppColors.warn
              : const Color(0xFF7C93B5),
      name: e.name,
      trailing: e.isDir
          ? null
          : Text(
              formatBytes(e.size ?? 0),
              style: const TextStyle(fontSize: 9.5, color: AppColors.textDim),
            ),
      onTap: () {
        if (e.isDir) {
          setState(() => _cwd = joinRemote(_cwd, e.name));
          _load();
        } else {
          _showFileActions(e);
        }
      },
      onLongPress: () => _showFileActions(e),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color color,
    required String name,
    required Widget? trailing,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.stroke),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ 操作菜单

  Future<void> _showFileActions(_FsEntry e) async {
    final path = joinRemote(_cwd, e.name);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101A2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    e.isDir ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
                    size: 15,
                    color: e.isDir ? AppColors.warn : AppColors.textDim,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Divider(),
              if (!e.isDir)
                _sheetAction(
                  icon: Icons.download_rounded,
                  label: '下载到手表',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _download(e, path);
                  },
                ),
              _sheetAction(
                icon: Icons.drive_file_rename_outline_rounded,
                label: '重命名',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _rename(e, path);
                },
              ),
              _sheetAction(
                icon: Icons.info_outline_rounded,
                label: '属性',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showAttrs(e, path);
                },
              ),
              _sheetAction(
                icon: Icons.delete_outline_rounded,
                label: '删除',
                color: AppColors.danger,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _delete(e, path);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final fg = color ?? AppColors.text;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ 属性

  Future<void> _showAttrs(_FsEntry e, String path) async {
    String sizeText = '—';
    int? mtime = e.mtime;
    try {
      final sftp = await _conn.sftp();
      final attrs = await sftp.stat(path);
      if (attrs.size != null) sizeText = formatBytes(attrs.size!);
      mtime = attrs.modifyTime ?? mtime;
    } catch (_) {}
    if (!mounted) return;
    final mtimeText = mtime == null
        ? '—'
        : formatTime(mtime * 1000);
    await showAppDialog<void>(
      context: context,
      title: Text(e.isDir ? '目录属性' : '文件属性'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KVRow(k: '名称', v: e.name),
          KVRow(k: '路径', v: compressPath(path, maxLen: 34)),
          KVRow(k: '类型', v: e.isDir ? '目录' : '普通文件'),
          KVRow(k: '大小', v: sizeText),
          KVRow(k: '修改时间', v: mtimeText),
        ],
      ),
      actions: [
        PillButton(
          label: '关闭',
          dense: true,
          filled: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ 重命名 / 删除

  Future<void> _rename(_FsEntry e, String path) async {
    final controller = TextEditingController(text: e.name);
    final ok = await showAppDialog<bool>(
      context: context,
      title: const Text('重命名'),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(fontSize: 12, color: AppColors.text),
        decoration: const InputDecoration(hintText: '新名称'),
      ),
      actions: [
        PillButton(
          label: '取消',
          dense: true,
          filled: false,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PillButton(
          label: '确定',
          dense: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    final newName = controller.text.trim();
    controller.dispose();
    if (ok != true || newName.isEmpty || newName == e.name) return;
    await _guard(() async {
      final sftp = await _conn.sftp();
      await sftp.rename(path, joinRemote(_cwd, newName));
      await _load();
    }, okMessage: '已重命名');
  }

  Future<void> _delete(_FsEntry e, String path) async {
    final ok = await showAppDialog<bool>(
      context: context,
      title: Text(e.isDir ? '删除目录？' : '删除文件？'),
      content: Text(
        e.isDir
            ? '将删除目录「${e.name}」（仅限空目录）\n此操作不可撤销！'
            : '将永久删除「${e.name}」\n此操作不可撤销！',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11.5, color: AppColors.text),
      ),
      actions: [
        PillButton(
          label: '取消',
          dense: true,
          filled: false,
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
    if (ok != true) return;
    await _guard(() async {
      final sftp = await _conn.sftp();
      if (e.isDir) {
        await sftp.rmdir(path);
      } else {
        await sftp.remove(path);
      }
      await _load();
    }, okMessage: '已删除');
  }

  // ------------------------------------------------------------ 新建目录

  Future<void> _newFolder() async {
    final controller = TextEditingController();
    final ok = await showAppDialog<bool>(
      context: context,
      title: const Text('新建目录'),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(fontSize: 12, color: AppColors.text),
        decoration: const InputDecoration(hintText: '目录名称'),
      ),
      actions: [
        PillButton(
          label: '取消',
          dense: true,
          filled: false,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PillButton(
          label: '创建',
          dense: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    final name = controller.text.trim();
    controller.dispose();
    if (ok != true || name.isEmpty || name.contains('/')) return;
    await _guard(() async {
      final sftp = await _conn.sftp();
      await sftp.mkdir(joinRemote(_cwd, name));
      await _load();
    }, okMessage: '目录已创建');
  }

  // ------------------------------------------------------------ 下载

  Future<void> _download(_FsEntry e, String path) async {
    int? size;
    try {
      final sftp = await _conn.sftp();
      size = (await sftp.stat(path)).size;
    } catch (_) {}

    final base = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/下载');
    if (!await dir.exists()) await dir.create(recursive: true);
    final destPath = _uniqueLocalPath(dir.path, e.name);

    final controller = TransferController(title: e.name);
    if (!mounted) return;
    final progressUi = showTransferProgress(context, controller);

    var cancelled = false;
    String? error;
    SftpFile? handle;
    IOSink? sink;
    Timer? watcher;
    try {
      final sftp = await _conn.sftp();
      handle = await sftp.open(path, mode: SftpFileOpenMode.read);
      final out = File(destPath).openWrite();
      sink = out;

      watcher = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (controller.cancelled && !cancelled) {
          cancelled = true;
          // 关闭接收端使下载流中断
          // ignore: discarded_futures
          out.close();
        }
      });

      final done = await handle.downloadTo(
        out,
        length: size,
        onProgress: (read) {
          controller.update(
            bytes: read,
            total: size,
            fraction: (size != null && size > 0) ? read / size : null,
            phase: size == null ? '已接收 ${formatBytes(read)}' : '下载中 …',
          );
        },
        closeDestination: false,
      );
      await out.flush();

      if (cancelled) {
        try {
          await File(destPath).delete();
        } catch (_) {}
        controller.update(phase: '已取消');
      } else {
        controller.update(
          bytes: done,
          total: size ?? done,
          fraction: 1,
          phase: '下载完成 · ${formatBytes(done)}',
        );
      }
    } catch (err) {
      error = _errText(err);
      if (cancelled) {
        try {
          await File(destPath).delete();
        } catch (_) {}
        controller.update(phase: '已取消');
      } else {
        try {
          await File(destPath).delete();
        } catch (_) {}
        controller.update(phase: '出错：$error');
      }
    } finally {
      watcher?.cancel();
      try {
        await handle?.close();
      } catch (_) {}
      if (!cancelled) {
        try {
          await sink?.close();
        } catch (_) {}
      }
      controller.markFinished();
    }

    await progressUi;

    if (!mounted) return;
    if (error != null && !cancelled) {
      await showAppDialog<void>(
        context: context,
        title: const Text('下载失败'),
        content: Text(
          error,
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
      return;
    }
    if (cancelled) {
      showToast(context, '已取消下载');
      return;
    }
    await showAppDialog<void>(
      context: context,
      title: const Text('下载完成'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            e.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF070D18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.stroke),
            ),
            child: SelectableText(
              destPath,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '文件已保存到应用外部目录，可通过 USB / 文件管理器取出',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10),
          ),
        ],
      ),
      actions: [
        PillButton(
          label: '好的',
          dense: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  String _uniqueLocalPath(String dirPath, String name) {
    var candidate = '$dirPath/$name';
    if (!File(candidate).existsSync()) return candidate;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    for (var i = 1; i < 100; i++) {
      candidate = '$dirPath/$stem ($i)$ext';
      if (!File(candidate).existsSync()) return candidate;
    }
    return '$dirPath/$stem-${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  // ------------------------------------------------------------ 上传

  Future<void> _uploadFlow() async {
    final how = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF101A2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '选择要上传的文件',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              _sheetAction(
                icon: Icons.folder_open_rounded,
                label: '从系统文件选择器选择',
                color: AppColors.primary,
                onTap: () => Navigator.of(ctx).pop('picker'),
              ),
              _sheetAction(
                icon: Icons.edit_note_rounded,
                label: '手动输入本地路径',
                onTap: () => Navigator.of(ctx).pop('manual'),
              ),
            ],
          ),
        ),
      ),
    );
    if (how == null) return;

    String? localPath;
    if (how == 'picker') {
      try {
        final result = await FilePicker.platform.pickFiles(withData: false);
        localPath = result?.files.single.path;
      } catch (_) {
        if (!mounted) return;
        showToast(context, '系统文件选择器不可用');
        return;
      }
      if (localPath == null) return;
    } else {
      localPath = await _askLocalPath();
      if (localPath == null) return;
    }

    final file = File(localPath);
    if (!await file.exists()) {
      if (mounted) showToast(context, '本地文件不存在：$localPath');
      return;
    }
    final fileName = localPath.split('/').last;
    if (fileName.isEmpty) return;
    final remotePath = joinRemote(_cwd, fileName);

    await _uploadFile(file, remotePath, fileName);
  }

  Future<String?> _askLocalPath() async {
    final controller = TextEditingController(text: '/sdcard/Download/');
    final ok = await showAppDialog<bool>(
      context: context,
      title: const Text('本地文件路径'),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          color: AppColors.text,
        ),
        decoration: const InputDecoration(hintText: '/sdcard/Download/a.txt'),
      ),
      actions: [
        PillButton(
          label: '取消',
          dense: true,
          filled: false,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PillButton(
          label: '确定',
          dense: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    final path = controller.text.trim();
    controller.dispose();
    if (ok != true || path.isEmpty) return null;
    return path;
  }

  Future<void> _uploadFile(File file, String remotePath, String name) async {
    final total = await file.length();
    final controller = TransferController(title: name);
    if (!mounted) return;
    final progressUi = showTransferProgress(context, controller);

    SftpFile? handle;
    RandomAccessFile? raf;
    var cancelled = false;
    String? error;
    var sent = 0;
    try {
      final sftp = await _conn.sftp();
      handle = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.write |
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate,
      );
      raf = await file.open();

      const chunkSize = 128 * 1024;
      while (true) {
        if (controller.cancelled) {
          cancelled = true;
          break;
        }
        final chunk = await raf.read(chunkSize);
        if (chunk.isEmpty) break;
        await handle.writeBytes(chunk, offset: sent);
        sent += chunk.length;
        controller.update(
          bytes: sent,
          total: total,
          fraction: total > 0 ? sent / total : null,
          phase: '上传中 …',
        );
      }

      if (cancelled) {
        controller.update(phase: '已取消');
        try {
          await sftp.remove(remotePath);
        } catch (_) {}
      } else {
        controller.update(
          bytes: total,
          total: total,
          fraction: 1,
          phase: '上传完成 · ${formatBytes(total)}',
        );
      }
    } catch (err) {
      error = _errText(err);
      controller.update(phase: '出错：$error');
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
      try {
        await handle?.close();
      } catch (_) {}
      controller.markFinished();
    }

    await progressUi;
    if (!mounted) return;

    if (error != null) {
      await showAppDialog<void>(
        context: context,
        title: const Text('上传失败'),
        content: Text(
          error,
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
      return;
    }
    if (cancelled) {
      showToast(context, '已取消上传');
    } else {
      showToast(context, '上传完成：$name');
      await _load();
    }
  }
}

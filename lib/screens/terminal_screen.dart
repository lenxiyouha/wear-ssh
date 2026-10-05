import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';

import '../state/app_model.dart';
import '../theme.dart';
import '../util/rotary_scroll.dart';
import '../widgets/common.dart';

/// 远程终端（交互式 shell）
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  static const List<String> _presets = [
    'ls -la',
    'df -h',
    'free -m',
    'uptime',
    'whoami',
    'uname -a',
    'cat /etc/os-release',
    'systemctl status ssh --no-pager',
    'top -b -n1 | head -15',
  ];

  final ScrollController _outScroll = ScrollController();
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  SSHSession? _session;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;

  bool _opening = true;
  bool _dead = false;
  String _exitInfo = '';
  String _buffer = '';
  final List<String> _history = [];
  int _histIdx = -1;

  int _cols = 40;
  int _rows = 18;

  Timer? _flushTimer;
  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);

  static final RegExp _ansi = RegExp(
    r'\x1B(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1B]*(?:\x07|\x1B\\)|[@-Z\\-_])',
  );

  @override
  void initState() {
    super.initState();
    RotaryScroll.attach(_outScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeResize();
  }

  @override
  void dispose() {
    RotaryScroll.detach(_outScroll);
    _flushTimer?.cancel();
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _outScroll.dispose();
    _input.dispose();
    _inputFocus.dispose();
    try {
      _session?.close();
    } catch (_) {}
    super.dispose();
  }

  // ------------------------------------------------------------ 会话

  Future<void> _open() async {
    final conn = AppScope.of(context).connection;
    if (conn == null) {
      setState(() {
        _opening = false;
        _dead = true;
        _exitInfo = '连接已断开';
      });
      return;
    }
    _maybeResize();
    try {
      final session = await conn.client.shell(
        pty: SSHPtyConfig(
          type: 'xterm-256color',
          width: _cols,
          height: _rows,
        ),
      );
      _session = session;
      _stdoutSub = session.stdout
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(_append, onError: (_) => _markDead(''));
      _stderrSub = session.stderr
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(_append, onError: (_) => _markDead(''));
      unawaited(session.done.then((_) {
        _markDead('');
      }).catchError((_) {
        _markDead('');
      }));
      if (!mounted) return;
      setState(() => _opening = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _dead = true;
        _exitInfo = '无法打开 shell：$e';
      });
    }
  }

  void _markDead(String _) {
    if (!mounted) return;
    final code = _session?.exitCode;
    setState(() {
      _dead = true;
      _exitInfo = code == null ? '会话已结束' : '会话已结束（退出码 $code）';
    });
  }

  void _maybeResize() {
    final size = MediaQuery.sizeOf(context);
    final newCols = ((size.width - 44) / 6.4).floor().clamp(24, 64);
    final newRows = ((size.height - 150) / 13.5).floor().clamp(6, 48);
    if (newCols == _cols && newRows == _rows) return;
    _cols = newCols;
    _rows = newRows;
    final session = _session;
    if (session != null && !_dead) {
      try {
        session.resizeTerminal(_cols, _rows);
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------ 输出

  void _append(String text) {
    if (text.isEmpty) return;
    _buffer += text.replaceAll('\r\n', '\n');
    if (_buffer.length > 120000) {
      _buffer = _buffer.substring(_buffer.length - 90000);
      final nl = _buffer.indexOf('\n');
      if (nl > 0 && nl < 2000) _buffer = _buffer.substring(nl + 1);
    }
    final now = DateTime.now();
    if (now.difference(_lastFlush).inMilliseconds > 80) {
      _flush();
    } else {
      _flushTimer ??= Timer(const Duration(milliseconds: 120), _flush);
    }
  }

  void _flush() {
    if (!mounted) return;
    _flushTimer?.cancel();
    _flushTimer = null;
    _lastFlush = DateTime.now();
    // 仅当用户本来就停在底部时才继续跟随滚动
    final wasAtBottom = !_outScroll.hasClients ||
        _outScroll.position.pixels >=
            _outScroll.position.maxScrollExtent - 24;
    setState(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_outScroll.hasClients || !wasAtBottom) return;
        _outScroll.jumpTo(_outScroll.position.maxScrollExtent);
      });
    });
  }

  /// 去转义 + 处理 \r 覆盖 + 截取末尾若干行
  List<String> _visibleLines() {
    final cleaned = _buffer.replaceAll(_ansi, '');
    final rawLines = cleaned.split('\n');
    final lines = <String>[];
    final start = rawLines.length > 500 ? rawLines.length - 500 : 0;
    for (var i = start; i < rawLines.length; i++) {
      final line = rawLines[i];
      lines.add(line.contains('\r') ? line.split('\r').last : line);
    }
    return lines;
  }

  // ------------------------------------------------------------ 输入

  void _send([String? preset]) {
    final session = _session;
    final text = (preset ?? _input.text);
    if (session == null || _dead || text.isEmpty) return;
    session.write(Uint8List.fromList(utf8.encode('$text\n')));
    _history.add(text);
    if (_history.length > 100) _history.removeAt(0);
    _histIdx = -1;
    _input.clear();
    _inputFocus.unfocus();
  }

  void _sendControl(int code) {
    final session = _session;
    if (session == null || _dead) return;
    session.write(Uint8List.fromList([code]));
  }

  void _historyUp() {
    if (_history.isEmpty) return;
    if (_histIdx == -1) _histIdx = _history.length - 1;
    setState(() => _input.text = _history[_histIdx]);
    if (_histIdx > 0) _histIdx--;
    _input.selection =
        TextSelection.collapsed(offset: _input.text.length);
  }

  Future<void> _showPresets() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101A2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 210,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              const Text(
                '常用命令（点击填入输入框）',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              for (final cmd in _presets)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() => _input.text = cmd);
                    _input.selection = TextSelection.collapsed(
                      offset: _input.text.length,
                    );
                    _inputFocus.requestFocus();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '\$ $cmd',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _clear() {
    setState(() => _buffer = '');
  }

  // ------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final conn = model.connection;

    if (conn == null && !_dead) {
      return _scaffold(
        child: const EmptyHint(
          icon: Icons.wifi_off_rounded,
          text: '连接已断开，终端不可用',
        ),
      );
    }

    final lines = _visibleLines();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 4, 11, 6),
          child: Column(
            children: [
              // 顶部工具行
              SizedBox(
                height: 26,
                child: Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        '终端 · ${conn?.config.name ?? ''}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    RoundIconButton(
                      icon: Icons.delete_sweep_rounded,
                      onTap: _clear,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              // 输出区
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
                  decoration: BoxDecoration(
                    color: AppColors.termBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Stack(
                    children: [
                      if (_opening)
                        const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(strokeWidth: 2.6),
                          ),
                        )
                      else
                        ListView.builder(
                          controller: _outScroll,
                          itemCount: lines.length,
                          itemBuilder: (_, i) => Text(
                            lines[i].isEmpty ? ' ' : lines[i],
                            style: const TextStyle(
                              fontSize: 10.5,
                              height: 1.25,
                              fontFamily: 'monospace',
                              color: AppColors.termFg,
                            ),
                          ),
                        ),
                      if (_dead && !_opening)
                        Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B1C22),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.danger),
                            ),
                            child: Text(
                              _exitInfo,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              // 快捷键行
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _chip('^C', onTap: () => _sendControl(3)),
                  const SizedBox(width: 6),
                  _chip('^D', onTap: () => _sendControl(4)),
                  const SizedBox(width: 6),
                  _chip('▲ 历史', onTap: _historyUp),
                  const SizedBox(width: 6),
                  _chip('⚡ 预设', onTap: _showPresets),
                ],
              ),
              const SizedBox(height: 5),
              // 输入行
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: TextField(
                        controller: _input,
                        focusNode: _inputFocus,
                        enabled: !_dead && !_opening,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppColors.text,
                        ),
                        decoration: const InputDecoration(
                          hintText: '输入命令 …',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 34,
                    height: 30,
                    child: Material(
                      color:
                          _dead ? const Color(0xFF1D2A42) : AppColors.primary,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: _dead ? null : () => _send(),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scaffold({required Widget child}) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Column(
            children: [
              WatchHeader(
                title: '终端',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(child: child),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, {required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

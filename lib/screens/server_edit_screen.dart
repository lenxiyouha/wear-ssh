import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/server_config.dart';
import '../state/app_model.dart';
import '../theme.dart';
import '../util/rotary_scroll.dart';
import '../widgets/common.dart';

/// 添加 / 编辑服务器
class ServerEditScreen extends StatefulWidget {
  const ServerEditScreen({super.key, this.existing});

  final ServerConfig? existing;

  @override
  State<ServerEditScreen> createState() => _ServerEditScreenState();
}

class _ServerEditScreenState extends State<ServerEditScreen> {
  final ScrollController _scroll = ScrollController();
  final _formKey = GlobalKey<FormState>();

  late final ServerConfig _config;
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _key;
  late final TextEditingController _keyPass;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    RotaryScroll.attach(_scroll);
    final src = widget.existing;
    _config = src?.copy() ??
        ServerConfig(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: '',
          host: '',
          username: '',
        );
    _name = TextEditingController(text: _config.name);
    _host = TextEditingController(text: _config.host);
    _port = TextEditingController(text: '${_config.port}');
    _username = TextEditingController(text: _config.username);
    _password = TextEditingController(text: _config.password);
    _key = TextEditingController(text: _config.privateKeyPem);
    _keyPass = TextEditingController(text: _config.keyPassphrase);
  }

  @override
  void dispose() {
    RotaryScroll.detach(_scroll);
    _scroll.dispose();
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    _key.dispose();
    _keyPass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKey = _config.authMethod == AuthMethod.privateKey;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Column(
            children: [
              WatchHeader(
                title: widget.existing == null ? '添加服务器' : '编辑服务器',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: EdgeFades(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.only(top: 2, bottom: 8),
                      children: [
                        _field(
                          label: '名称',
                          hint: '例如：家里的 VPS',
                          controller: _name,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? '请输入名称'
                              : null,
                        ),
                        _field(
                          label: '主机',
                          hint: 'IP 或域名，如 192.168.1.10',
                          controller: _host,
                          keyboard: TextInputType.url,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? '请输入主机地址'
                              : null,
                        ),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _field(
                                label: '端口',
                                controller: _port,
                                keyboard: TextInputType.number,
                                validator: (v) {
                                  final p = int.tryParse(v?.trim() ?? '');
                                  if (p == null || p < 1 || p > 65535) {
                                    return '端口无效';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              flex: 3,
                              child: _field(
                                label: '用户名',
                                hint: 'root',
                                controller: _username,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? '请输入用户名'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '认证方式',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textDim,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _authChip(
                              selected: !isKey,
                              icon: Icons.password_rounded,
                              label: '密码',
                              onTap: () => setState(
                                () => _config.authMethod = AuthMethod.password,
                              ),
                            ),
                            const SizedBox(width: 7),
                            _authChip(
                              selected: isKey,
                              icon: Icons.vpn_key_rounded,
                              label: '私钥',
                              onTap: () => setState(
                                () =>
                                    _config.authMethod = AuthMethod.privateKey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        if (!isKey)
                          _field(
                            label: '密码',
                            hint: '登录密码',
                            controller: _password,
                            obscure: _obscure,
                            suffix: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 26,
                              ),
                              iconSize: 15,
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: AppColors.textDim,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          )
                        else ...[
                          Row(
                            children: [
                              const Text(
                                '私钥 (PEM)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textDim,
                                ),
                              ),
                              const Spacer(),
                              _miniAction(
                                label: '粘贴',
                                onTap: _pasteKey,
                              ),
                              const SizedBox(width: 6),
                              _miniAction(label: '选择文件', onTap: _pickKeyFile),
                            ],
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _key,
                            maxLines: 4,
                            minLines: 3,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontFamily: 'monospace',
                              color: AppColors.text,
                            ),
                            decoration: const InputDecoration(
                              hintText:
                                  '-----BEGIN OPENSSH PRIVATE KEY-----\n…',
                            ),
                            validator: (v) {
                              if (_config.authMethod != AuthMethod.privateKey) {
                                return null;
                              }
                              if (v == null || v.trim().isEmpty) {
                                return '请粘贴或选择私钥文件';
                              }
                              if (!v.contains('PRIVATE KEY')) {
                                return '看起来不是 PEM/OpenSSH 私钥';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 7),
                          _field(
                            label: '私钥口令（可选）',
                            hint: '若私钥已加密则填写',
                            controller: _keyPass,
                            obscure: true,
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            PillButton(
                              label: '取消',
                              filled: false,
                              dense: true,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: PillButton(
                                label: '保存',
                                icon: Icons.check_rounded,
                                dense: true,
                                expanded: true,
                                onPressed: _save,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
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

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textDim),
          ),
          const SizedBox(height: 3),
          TextFormField(
            controller: controller,
            keyboardType: keyboard,
            obscureText: obscure,
            style: const TextStyle(fontSize: 12, color: AppColors.text),
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: suffix == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: suffix,
                    ),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 28, minHeight: 26),
            ),
            validator: validator,
          ),
        ],
      ),
    );
  }

  Widget _authChip({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: selected ? const Color(0xFF0F3B49) : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.stroke,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: selected ? AppColors.primary : AppColors.textDim,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniAction({required String label, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.primary),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ 导入私钥

  Future<void> _pasteKey() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) showToast(context, '剪贴板为空');
      return;
    }
    setState(() => _key.text = text);
    if (mounted) showToast(context, '已粘贴私钥');
  }

  Future<void> _pickKeyFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final content = await File(path).readAsString();
      setState(() => _key.text = content);
      if (mounted) showToast(context, '已导入私钥文件');
    } catch (e) {
      if (mounted) {
        showToast(context, '读取文件失败，可改用"粘贴"方式');
      }
    }
  }

  // ------------------------------------------------------------ 保存

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    form.save();

    _config
      ..name = _name.text.trim()
      ..host = _host.text.trim()
      ..port = int.parse(_port.text.trim())
      ..username = _username.text.trim()
      ..password = _password.text
      ..privateKeyPem = _key.text
      ..keyPassphrase = _keyPass.text;

    // 主机或端口发生变化时，旧的指纹不再适用
    final old = widget.existing;
    if (old != null && (old.host != _config.host || old.port != _config.port)) {
      _config.hostKeyFingerprint = null;
    }

    await AppScope.of(context).saveServer(_config);
    if (!mounted) return;
    showToast(context, '已保存');
    Navigator.of(context).pop();
  }
}

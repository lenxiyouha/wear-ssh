import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// 进入应用时弹出的免责声明
class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key, required this.onAccept});

  final VoidCallback onAccept;

  static const String version = '1.0.0';

  static const List<_Clause> _clauses = [
    _Clause(
      '开源与用途',
      '本应用（圆表SSH）是一款开源的 SSH / SFTP 客户端工具，仅供学习研究，'
      '以及管理您本人拥有或已明确获得授权的服务器。禁止用于任何非法用途。',
    ),
    _Clause(
      '凭据存储',
      '服务器地址、用户名、密码、私钥等凭据以明文形式保存在本机应用沙盒内。'
      '若设备被 root、被盗或被他人操作，存在凭据泄露风险。建议优先使用密钥认证、'
      '为私钥设置口令，并避免保存高权限账号。',
    ),
    _Clause(
      '主机指纹',
      '连接过程使用 SSH 标准加密传输。首次连接时需要您确认服务器指纹；'
      '若跳过校验或错误确认指纹，可能遭受中间人攻击，相关风险由您自行承担。',
    ),
    _Clause(
      '操作风险',
      '通过本应用执行的远程命令、文件上传 / 下载 / 删除、重命名等操作，'
      '均直接作用于目标服务器。请务必确认命令与路径无误后再执行；'
      '因误操作导致的数据丢失、服务中断等后果由您自行承担。',
    ),
    _Clause(
      '免责条款',
      '本软件按"现状"提供，不附带任何明示或默示的担保。'
      '作者不对任何数据丢失、服务中断、设备损坏以及直接或间接损失承担责任。',
    ),
    _Clause(
      '视为同意',
      '点击"同意并继续"，即表示您已完整阅读、理解并接受以上全部条款；'
      '点击"拒绝并退出"将立即关闭应用。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              const WatchHeader(title: '使用免责声明'),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < _clauses.length; i++) ...[
                          if (i > 0) const SizedBox(height: 7),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${i + 1}. ${_clauses[i].title}  ',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                TextSpan(
                                  text: _clauses[i].text,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    height: 1.45,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            '圆表SSH v$version · MIT 开源协议',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.textDim,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  PillButton(
                    label: '拒绝并退出',
                    filled: false,
                    dense: true,
                    danger: true,
                    onPressed: () => SystemNavigator.pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PillButton(
                      label: '同意并继续',
                      icon: Icons.check_rounded,
                      dense: true,
                      expanded: true,
                      onPressed: onAccept,
                    ),
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
}

class _Clause {
  const _Clause(this.title, this.text);

  final String title;
  final String text;
}

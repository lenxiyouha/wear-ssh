import 'dart:convert';

/// 认证方式
enum AuthMethod {
  password,
  privateKey,
}

/// 一台已保存的 SSH 服务器配置
class ServerConfig {
  ServerConfig({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.authMethod = AuthMethod.password,
    this.password = '',
    this.privateKeyPem = '',
    this.keyPassphrase = '',
    this.hostKeyFingerprint,
    this.lastConnectedMs,
  });

  final String id;
  String name;
  String host;
  int port;
  String username;
  AuthMethod authMethod;

  /// 密码认证的密码（明文保存于应用沙盒，请阅读免责声明）
  String password;

  /// PEM/OpenSSH 格式私钥文本
  String privateKeyPem;

  /// 私钥口令（若私钥已加密）
  String keyPassphrase;

  /// 已信任的主机指纹 `SHA256:...`
  String? hostKeyFingerprint;

  int? lastConnectedMs;

  String get address => '$host:$port';

  String get login => '$username@$host';

  ServerConfig copy() => ServerConfig(
        id: id,
        name: name,
        host: host,
        port: port,
        username: username,
        authMethod: authMethod,
        password: password,
        privateKeyPem: privateKeyPem,
        keyPassphrase: keyPassphrase,
        hostKeyFingerprint: hostKeyFingerprint,
        lastConnectedMs: lastConnectedMs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'authMethod': authMethod.name,
        'password': password,
        'privateKeyPem': privateKeyPem,
        'keyPassphrase': keyPassphrase,
        'hostKeyFingerprint': hostKeyFingerprint,
        'lastConnectedMs': lastConnectedMs,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        id: (json['id'] as String?) ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: (json['name'] as String?) ?? '',
        host: (json['host'] as String?) ?? '',
        port: (json['port'] as num?)?.toInt() ?? 22,
        username: (json['username'] as String?) ?? '',
        authMethod: json['authMethod'] == AuthMethod.privateKey.name
            ? AuthMethod.privateKey
            : AuthMethod.password,
        password: (json['password'] as String?) ?? '',
        privateKeyPem: (json['privateKeyPem'] as String?) ?? '',
        keyPassphrase: (json['keyPassphrase'] as String?) ?? '',
        hostKeyFingerprint: json['hostKeyFingerprint'] as String?,
        lastConnectedMs: (json['lastConnectedMs'] as num?)?.toInt(),
      );

  static String encodeList(List<ServerConfig> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<ServerConfig> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => ServerConfig.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

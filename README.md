<p align="center">
  <img src="assets/icon/icon_source.png" width="96" height="96" alt="圆表SSH 图标"/>
</p>

<h1 align="center">圆表SSH · Wear SSH</h1>

<p align="center">
  适配<b>圆形表盘</b>的 Wear OS SSH 客户端<br/>
  服务器信息 · SFTP 文件管理（上传/下载） · 远程终端
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.47.x-02569B?logo=flutter&logoColor=white"/>
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Wear%20OS%20%7C%20Android-3DDC84?logo=android&logoColor=white"/>
  <img alt="License" src="https://img.shields.io/badge/License-MIT-green"/>
  <img alt="CI" src="https://github.com/lenxiyouha/wear-ssh/actions/workflows/build-apk.yml/badge.svg"/>
</p>

---

一块圆表，就能连上你的服务器：看状态、管文件、跑命令。

## 功能特性

| 模块 | 能力 |
| --- | --- |
| 🛡 免责声明 | 每次进入应用弹出使用免责声明，同意后才能继续 |
| 🖥 服务器管理 | 增 / 删 / 改，**密码** 与 **SSH 私钥**（PEM/OpenSSH，支持加密私钥）双认证 |
| 🔐 连接安全 | 首次连接确认 **主机指纹**（SHA256），指纹变更时红色警告；已信任指纹本地记住 |
| 📊 服务器信息 | 系统发行版、内核、主机名、运行时长与负载、CPU 型号/核数、内存、根分区、局域网 IP、**响应延迟**、SSH 服务端版本 |
| 📁 文件管理 | SFTP 浏览 / 进入 / 返回 / 新建目录 / 重命名 / 删除 / 查看属性，目录优先排序 |
| ⬆️ 上传 | 系统文件选择器 或 手动输入本地路径，**带进度与取消** |
| ⬇️ 下载 | 保存到手表本地，**带进度与取消**，完成后展示完整保存路径 |
| 💻 终端 | 交互式 shell、`^C` / `^D` 控制键、命令历史、常用命令预设、清屏 |
| ⌚ Wear 适配 | 圆形布局、**旋转表冠滚动**、连接期间**屏幕常亮**、OLED 深色主题、中文界面 |

最低支持：**Wear OS 2.1+ / Android 8.0（API 26）**，应用可脱离手机独立运行（Standalone）。

## 界面导览

```
启动
 └─ 免责声明（同意 / 拒绝退出）
     └─ 服务器列表（长按卡片：编辑 / 删除 / 重置指纹）
         └─ 连接进度 ⇢ 指纹确认（如首次）
             └─ 会话中心
                 ├─ 服务器信息   （系统 / 连接 / 运行状态 + 刷新）
                 ├─ 文件管理     （SFTP 浏览 · 上传 · 下载 · 重命名 · 删除）
                 ├─ 终端         （shell · ^C^D · 历史 · 预设命令）
                 └─ 编辑服务器 / 断开连接
```

## 编译

### 方式一：GitHub Actions（推荐，零环境依赖）

1. 推送到本仓库（或 Fork 后推送）；
2. 打开 **Actions → 构建 APK → Run workflow**（push 到主分支也会自动触发）；
3. 构建完成后在该次运行页面底部 **Artifacts** 下载 `app-release.apk`。

> CI 会先执行 `flutter analyze` 质量门禁，再产出 Release APK。

### 方式二：本地编译

环境要求：Flutter 3.47.x（stable）、JDK 17、Android SDK（Platform 36）。

```bash
flutter pub get
flutter analyze
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

Release 包默认使用 debug 签名，便于个人侧载安装；如需上架 Play，请替换为自己的 keystore（见 `android/app/build.gradle.kts`）。

### 安装到手表

```bash
# 手表开启：设置 → 系统 → 开发者选项 → ADB 调试（及通过蓝牙/WiFi 调试）
adb -s <设备号> install -r app-release.apk
```

也可通过蓝牙 / 手表文件管理器传输 APK 后点击安装（需允许未知来源）。

## 应用图标

> 深空蓝黑对角渐变 + 圆形表环 + 青色终端提示符 `>_` + 环上绿色「已连接」节点。
> 深色背景适配 OLED 省电；符号化设计保证在 96px 甚至更小的手表启动器上依然清晰。

重新生成图标：

```bash
python3 tool/generate_icon.py        # 生成 1024 源图 / 前景 / 背景 / Wear 横幅
dart run flutter_launcher_icons      # 生成各密度 mipmap 与自适应图标
```

## 数据与安全

- 服务器配置（含密码 / 私钥）保存在应用内 `SharedPreferences`，为**明文存储**，请勿保存高权限账号；建议使用**密钥 + 口令**认证。
- 网络传输使用 SSH 标准加密；`INTERNET` 是应用唯一申请的权限。
- 下载文件保存在：`/storage/emulated/0/Android/data/dev.wearssh.app/files/下载/`，可通过 USB（MTP）或文件管理器取出。
- 应用禁用了系统备份（`android:allowBackup=false`），凭据不会同步到云端。

## 已知限制

- 终端为轻量实现：输出会剥离 ANSI 转义序列，**不模拟完整 VT100**。执行命令、查看输出没有问题；`vim` / `htop` 这类全屏 TUI 不适用（`top -b -n1` 之类的批量输出可用）。
- 上传依赖系统文件选择器（SAF）；个别 Wear 表盘系统若无文件选择器，可改用「手动输入本地路径」。
- 删除非空目录需先清空（SFTP 协议限制）。
- 表冠滚动方向、特殊输入法适配如与你的设备不符，欢迎提 Issue。

## 项目结构

```
lib/
├── main.dart                    # 入口、免责声明门控、全局主题/字号钳制
├── app_nav.dart                 # 全局 NavigatorKey（SSH 回调弹窗用）
├── theme.dart                   # 深色主题与配色
├── models/server_config.dart    # 服务器配置模型（JSON 序列化）
├── state/app_model.dart         # 状态中枢：服务器列表 + SSH 连接生命周期
├── ssh/
│   ├── errors.dart              # 错误 → 中文友好提示
│   └── host_info.dart           # 并发执行探测命令，采集服务器信息
├── util/
│   ├── wear_bridge.dart         # 原生通道：表冠事件 / 屏幕常亮
│   ├── rotary_scroll.dart       # 表冠 → 列表滚动分发
│   └── formatters.dart          # 字节 / 时间 / 路径格式化
├── widgets/common.dart          # 圆表组件：头部、胶囊按钮、卡片、传输进度
└── screens/
    ├── disclaimer_screen.dart   # 免责声明
    ├── server_list_screen.dart  # 首页列表 + 连接流程 + 指纹确认
    ├── server_edit_screen.dart  # 添加/编辑服务器（含私钥导入）
    ├── session_screen.dart      # 会话中心
    ├── server_info_screen.dart  # 服务器信息
    ├── file_browser_screen.dart # SFTP 文件管理
    └── terminal_screen.dart     # 远程终端
```

## 技术栈

[Flutter](https://flutter.dev) 3.47 · [dartssh2](https://pub.dev/packages/dartssh2) 4.1（纯 Dart SSH/SFTP）· shared_preferences · file_picker · path_provider

## License

[MIT](LICENSE) — 使用本软件产生的任何服务器操作风险自负，请先阅读应用内免责声明。

import 'package:flutter/material.dart';

/// 全局导航键：供 SSH 回调（如主机指纹确认）在无页面上下文时弹出对话框
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

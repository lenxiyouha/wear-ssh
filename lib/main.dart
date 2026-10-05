import 'package:flutter/material.dart';

import 'app_nav.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/server_list_screen.dart';
import 'state/app_model.dart';
import 'theme.dart';
import 'util/rotary_scroll.dart';
import 'util/wear_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WearBridge.init();
  WearBridge.onRotary = RotaryScroll.handle;
  runApp(const WearSshApp());
}

class WearSshApp extends StatefulWidget {
  const WearSshApp({super.key});

  @override
  State<WearSshApp> createState() => _WearSshAppState();
}

class _WearSshAppState extends State<WearSshApp> {
  final AppModel _model = AppModel();

  @override
  void initState() {
    super.initState();
    _model.load();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  /// 表盘上布局敏感，钳制系统字号缩放，避免圆表 UI 溢出
  TextScaler _clampScaler(BuildContext context) {
    final scale = MediaQuery.of(context).textScaler.scale(1.0);
    return TextScaler.linear(scale.clamp(0.85, 1.15));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '圆表SSH',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      navigatorKey: appNavigatorKey,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: _clampScaler(context)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: AppScope(
        model: _model,
        child: ListenableBuilder(
          listenable: _model,
          builder: (context, _) => _StartupGate(model: _model),
        ),
      ),
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate({required this.model});

  final AppModel model;

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _disclaimerAccepted = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.model.loaded) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 3),
              SizedBox(height: 12),
              Text(
                '圆表SSH',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_disclaimerAccepted) {
      return DisclaimerScreen(
        onAccept: () => setState(() => _disclaimerAccepted = true),
      );
    }

    return const ServerListScreen();
  }
}

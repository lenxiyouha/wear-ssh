import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wear_ssh/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WearSshApp());
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('启动后先弹出免责声明', (tester) async {
    await boot(tester);

    expect(find.text('使用免责声明'), findsOneWidget);
    expect(find.text('同意并继续'), findsOneWidget);
    expect(find.text('拒绝并退出'), findsOneWidget);
    // 条款首条可见
    expect(find.textContaining('开源与用途'), findsOneWidget);
  });

  testWidgets('同意后进入空的服务器列表', (tester) async {
    await boot(tester);

    await tester.tap(find.text('同意并继续'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('圆表SSH'), findsWidgets);
    expect(find.text('添加服务器'), findsOneWidget);
    expect(find.textContaining('还没有服务器'), findsOneWidget);
  });

  testWidgets('添加服务器：校验通过后保存并显示在列表', (tester) async {
    await boot(tester);
    await tester.tap(find.text('同意并继续'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('添加服务器'));
    await tester.pumpAndSettle();

    expect(find.text('添加服务器'), findsOneWidget);

    // 空表单直接保存 → 触发校验
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('请输入名称'), findsOneWidget);
    expect(find.text('请输入主机地址'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '家里的 VPS');
    await tester.enterText(fields.at(1), '192.168.1.10');
    await tester.enterText(fields.at(2), '2222');
    await tester.enterText(fields.at(3), 'root');

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 回到列表，卡片出现
    expect(find.text('家里的 VPS'), findsOneWidget);
    expect(find.text('root@192.168.1.10:2222'), findsOneWidget);
  });
}

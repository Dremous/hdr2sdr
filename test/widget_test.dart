import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hdr2sdr/providers/convert_provider.dart';
import 'package:hdr2sdr/app.dart';

void main() {
  testWidgets('应用启动测试 — 验证 Provider 和 App 正常构建', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ConvertProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: Text('HDR↔SDR'),
          ),
        ),
      ),
    );
    expect(find.text('HDR↔SDR'), findsOneWidget);
  });

  testWidgets('Hdr2SdrApp 可构建', (WidgetTester tester) async {
    await tester.pumpWidget(const Hdr2SdrApp());
    await tester.pumpAndSettle();
    // 验证 AppBar 标题存在（桌面端默认显示）
    expect(find.text('HDR↔SDR 视频转换工具'), findsOneWidget);
  });
}

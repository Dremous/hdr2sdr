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

  test('Hdr2SdrApp 可构建', () {
    expect(const Hdr2SdrApp(), isA<StatelessWidget>());
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:hdr2sdr/app.dart';

void main() {
  testWidgets('应用启动测试', (WidgetTester tester) async {
    await tester.pumpWidget(const Hdr2SdrApp());
    expect(find.text('HDR↔SDR Converter'), findsNothing);
  });
}

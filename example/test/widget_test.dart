import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3xpressive_indicators/m3xpressive_indicators.dart';

void main() {
  testWidgets('example app renders all indicator widgets', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.byType(M3XCircularWavyProgressIndicator), findsNWidgets(2));
    expect(find.byType(M3XCircularWavyLoadingIndicator), findsOneWidget);
    expect(find.byType(M3XLinearWavyProgressIndicator), findsNWidgets(2));
  });
}

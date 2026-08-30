import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3xpressive_indicators/m3xpressive_indicators.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets(
      'M3XCircularWavyProgressIndicator builds in loading and determinate modes',
      (tester) async {
    await tester.pumpWidget(wrap(const M3XCircularWavyProgressIndicator()));
    expect(find.byType(M3XCircularWavyProgressIndicator), findsOneWidget);

    await tester
        .pumpWidget(wrap(const M3XCircularWavyProgressIndicator(value: 0.4)));
    expect(find.byType(M3XCircularWavyProgressIndicator), findsOneWidget);
  });

  testWidgets(
      'M3XLinearWavyProgressIndicator builds in loading and determinate modes',
      (tester) async {
    await tester.pumpWidget(wrap(const M3XLinearWavyProgressIndicator()));
    expect(find.byType(M3XLinearWavyProgressIndicator), findsOneWidget);

    await tester
        .pumpWidget(wrap(const M3XLinearWavyProgressIndicator(value: 0.4)));
    expect(find.byType(M3XLinearWavyProgressIndicator), findsOneWidget);
  });

  testWidgets(
      'M3XCircularWavyLoadingIndicator builds and animates without throwing',
      (tester) async {
    await tester.pumpWidget(wrap(const M3XCircularWavyLoadingIndicator()));
    expect(find.byType(M3XCircularWavyLoadingIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(M3XCircularWavyLoadingIndicator), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taji/shared/widgets/taji_logo.dart';

void main() {
  testWidgets('Taji logo renders the shared brand', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TajiLogo())),
    );
    expect(find.text('taji'), findsOneWidget);
  });
}

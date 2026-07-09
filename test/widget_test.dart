import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driver/features/home/home_view.dart';

void main() {
  testWidgets('Dashboard screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: const MaterialApp(home: HomeView(showMap: false)),
      ),
    );

    expect(find.text('Go Online'), findsOneWidget);
    expect(find.text('You are offline'), findsOneWidget);
  });
}

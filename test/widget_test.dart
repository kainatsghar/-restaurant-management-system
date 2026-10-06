// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_management_system/main.dart';

void main() {
  testWidgets('RestaurantApp loads Categories screen and navigates to Add Category',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RestaurantApp());

    // Verify that the Categories title and search bar are present
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Search Categories'), findsOneWidget);

    // Tap on "+" button to navigate to Add Category
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Verify we navigated to Add New Category screen
    expect(find.text('Add New Category'), findsOneWidget);
    expect(find.text('Enter Category Name'), findsOneWidget);
    expect(find.text('Upload Image'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // Verify back on Categories screen
    expect(find.text('Categories'), findsOneWidget);
  });
}

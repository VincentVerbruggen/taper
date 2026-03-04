import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheel_picker/wheel_picker.dart';

import 'package:taper/screens/log/widgets/time_picker.dart';

void main() {
  testWidgets('renders formatted date and time buttons', (tester) async {
    final date = DateTime(2026, 2, 23, 14, 30);
    final time = const TimeOfDay(hour: 14, minute: 30);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimePicker(
            date: date,
            time: time,
            onDateChanged: (_) {},
            onTimeChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Date label uses the shared short formatter ("Mon, Feb 23").
    expect(find.text('Mon, Feb 23'), findsOneWidget);
    // Time label stays in 24h format.
    expect(find.text('14:30'), findsOneWidget);
  });

  testWidgets('time button opens wheel picker dialog and applies selection', (
    tester,
  ) async {
    final date = DateTime(2026, 2, 23, 14, 30);
    final initialTime = const TimeOfDay(hour: 14, minute: 30);
    TimeOfDay? pickedTime;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimePicker(
            date: date,
            time: initialTime,
            onDateChanged: (_) {},
            onTimeChanged: (value) => pickedTime = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.access_time));
    await tester.pumpAndSettle();

    expect(find.text('Set time'), findsOneWidget);
    // Two wheels: hour + minute.
    expect(find.byType(WheelPicker), findsNWidgets(2));
    // Keys make it explicit which wheel is which.
    expect(find.byKey(const ValueKey('time_wheel_hour')), findsOneWidget);
    expect(find.byKey(const ValueKey('time_wheel_minute')), findsOneWidget);

    // No drag in this test: just confirm dialog returns a value and callback runs.
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(pickedTime, isNotNull);
    expect(pickedTime!.hour, 14);
    expect(pickedTime!.minute, 30);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:msi_clock/main.dart';
import 'package:msi_clock/models/soap_config.dart';
import 'package:msi_clock/providers/punch_provider.dart';

// Mock SOAP config for testing
final mockSoapConfig = SoapConfig(
  endpoint: 'https://msiwebtrax.com',
  username: 'test_user',
  password: 'test_pass',
  clientId: 'test_client',
);

Widget createTestApp() {
  return ChangeNotifierProvider(
    create: (_) => PunchProvider(mockSoapConfig),
    child: const MSIClockApp(),
  );
}

void main() {
  testWidgets('Basic UI elements test', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createTestApp());

    // Verify that the language toggle is present
    expect(find.text('EN'), findsOneWidget);

    // Verify that the employee ID input field is present
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Enter Employee ID'), findsOneWidget);

    // Verify that the punch button is present
    expect(find.text('PUNCH'), findsOneWidget);

    // Verify that the company name is present
    expect(find.text('Metro Staff Inc.'), findsOneWidget);

    // Verify that the online/offline status is present
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('Language toggle test', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createTestApp());

    // Initially in English
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('Enter Employee ID'), findsOneWidget);
    expect(find.text('PUNCH'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);

    // Tap the language toggle
    await tester.tap(find.byType(IconButton));
    await tester.pump();

    // Now in Spanish
    expect(find.text('ES'), findsOneWidget);
    expect(find.text('Ingrese ID de Empleado'), findsOneWidget);
    expect(find.text('MARCAR'), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget);
  });

  testWidgets('Empty ID validation test', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createTestApp());

    // Try to punch without entering an ID
    await tester.tap(find.text('PUNCH'));
    await tester.pump();

    // Verify that an error message is shown
    expect(find.text('Please enter employee ID'), findsOneWidget);

    // Switch to Spanish and try again
    await tester.tap(find.byType(IconButton));
    await tester.pump();

    await tester.tap(find.text('MARCAR'));
    await tester.pump();

    // Verify that the error message is in Spanish
    expect(find.text('Por favor ingrese ID de empleado'), findsOneWidget);
  });

  testWidgets('ID input test', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createTestApp());

    // Enter an employee ID
    await tester.enterText(find.byType(TextField), '12345');
    expect(find.text('12345'), findsOneWidget);

    // Verify that the text field is cleared after punching
    await tester.tap(find.text('PUNCH'));
    await tester.pump();
    expect(find.text('12345'), findsNothing);
  });
}

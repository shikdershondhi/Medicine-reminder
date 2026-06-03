import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_reminder/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App launches successfully in offline mode and renders landing UI', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(isFirebaseConfigured: false),
      ),
    );

    // Verify that the landing app title 'MedTrack' appears on screen.
    expect(find.text('MedTrack'), findsWidgets);
  });
}

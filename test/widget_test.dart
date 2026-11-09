import 'package:flutter_test/flutter_test.dart';
import 'package:iwardrobe/main.dart';

void main() {
  testWidgets('placeholder app inflates (task 001 smoke test)', (tester) async {
    await tester.pumpWidget(const IwardrobeApp());

    expect(find.text('iWardrobe (scaffold)'), findsOneWidget);
  });
}

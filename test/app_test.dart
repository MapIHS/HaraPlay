import 'package:flutter_test/flutter_test.dart';
import 'package:haraplay/app/app.dart';

void main() {
  testWidgets('app starts and shows the HaraPlay title', (tester) async {
    await tester.pumpWidget(const HaraPlayApp());

    expect(find.text('HaraPlay'), findsOneWidget);
  });
}

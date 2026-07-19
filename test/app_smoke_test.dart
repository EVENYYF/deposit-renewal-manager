import 'package:deposit_renewal_manager/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows deposit renewal app shell', (tester) async {
    await tester.pumpWidget(const DepositRenewalApp());
    expect(find.text('存款续期'), findsOneWidget);
  });
}

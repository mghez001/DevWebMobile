import 'package:flutter_test/flutter_test.dart';

import 'package:gestionnaire_appels/main.dart';

void main() {
  testWidgets("L'application démarre sur le journal", (tester) async {
    await tester.pumpWidget(const GestionnaireAppelsApp());
    expect(find.text('Journal'), findsWidgets);
  });
}

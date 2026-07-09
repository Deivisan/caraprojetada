import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:caraprojetada/main.dart';
import 'package:caraprojetada/services/api_service.dart';
import 'package:caraprojetada/services/prefs_service.dart';

void main() {
  testWidgets('app inicia e mostra a tela inicial', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefsService = await UserPrefsService.initialize();

    await tester.pumpWidget(
      CaraProjetadaApp(
        prefs: prefsService.prefs,
        prefsService: prefsService,
        api: ApiService(),
      ),
    );
    await tester.pumpAndSettle();

    // primeiro acesso mostra o onboarding (sem erros de layout/overflow)
    expect(find.text('Modo de Apresentacao'), findsOneWidget);
  });
}

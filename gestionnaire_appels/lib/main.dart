import 'package:flutter/material.dart';

import 'screens/accueil_screen.dart';
import 'services/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Le gestionnaire écoute les appels entrants dès le démarrage.
  Services.gestionnaire.demarrer();

  runApp(const GestionnaireAppelsApp());
}

/// Racine de l'application : thème + premier écran.
class GestionnaireAppelsApp extends StatelessWidget {
  const GestionnaireAppelsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Gestionnaire d'appels",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const AccueilScreen(),
    );
  }
}

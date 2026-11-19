import 'package:flutter/material.dart';

import 'screens/accueil_screen.dart';
import 'services/services.dart';
import 'theme.dart';
import 'widgets/couche_appels.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Démarre le gestionnaire (écoute des appels) et l'état de l'interface.
  Services.initialiser();

  runApp(const GestionnaireAppelsApp());
}

/// Racine de l'application : thème + structure + couche d'appels.
class GestionnaireAppelsApp extends StatelessWidget {
  const GestionnaireAppelsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Gestionnaire d'appels",
      debugShowCheckedModeBanner: false,
      theme: construireTheme(),
      // La couche d'appels est au-dessus de toutes les pages :
      // l'appel entrant bloque l'écran où que l'on soit.
      builder: (context, child) =>
          CoucheAppels(child: child ?? const SizedBox.shrink()),
      home: const AccueilScreen(),
    );
  }
}

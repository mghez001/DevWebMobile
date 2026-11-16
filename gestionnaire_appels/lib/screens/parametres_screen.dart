import 'package:flutter/material.dart';

import '../models/modeles.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/en_tete_page.dart';

/// Paramètres : Ne pas déranger, compte SIP… (d'autres réglages viendront).
class ParametresScreen extends StatelessWidget {
  const ParametresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const EnTetePage(
          titre: 'Paramètres',
          sousTitre: 'Réglages du gestionnaire d’appels',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TitreSection('Disponibilité'),
              Carte(
                child: StreamBuilder<List<Regle>>(
                  stream: Services.regles.surveiller(),
                  builder: (context, snapshot) {
                    final actif =
                        Services.nePasDerangerActif(snapshot.data ?? const []);
                    return SwitchListTile(
                      value: actif,
                      onChanged: Services.definirNePasDeranger,
                      secondary: Icon(
                        actif
                            ? Icons.do_not_disturb_on_rounded
                            : Icons.do_not_disturb_off_rounded,
                        color: actif ? Couleurs.signal : Couleurs.texteDoux,
                      ),
                      title: const Text('Ne pas déranger'),
                      subtitle: const Text(
                          'Tous les appels vont sur la messagerie, sauf les favoris'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const TitreSection('Compte'),
              Carte(
                child: ListenableBuilder(
                  listenable: Services.etat,
                  builder: (context, _) {
                    final (couleur, texte) =
                        etatConnexionAffiche(Services.etat.connexion);
                    return ListTile(
                      leading: const Icon(Icons.dns_rounded),
                      title: const Text('Serveur SIP'),
                      subtitle: Row(
                        children: [
                          Icon(Icons.circle, size: 9, color: couleur),
                          const SizedBox(width: 6),
                          Text(texte),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => ouvrirConnexionSip(context),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'D’autres réglages arriveront ici : horaires, calendrier, '
                  'règles personnalisées…',
                  style: TextStyle(color: Couleurs.texteDoux, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/appel_entrant_screen.dart';
import '../services/etat_appels.dart';
import '../services/services.dart';
import '../theme.dart';
import 'formats.dart';

/// Couche posée au-dessus de toute l'appli (MaterialApp.builder) :
///  - barre « appel en cours » en haut, sur toutes les pages ;
///  - écran plein « appel entrant », par-dessus tout le reste.
class CoucheAppels extends StatelessWidget {
  const CoucheAppels({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Services.etat,
      builder: (context, _) {
        final actif = Services.etat.appelActif;
        final sonne = Services.etat.appelQuiSonne;

        // La structure reste la même quel que soit l'état (pour ne pas
        // recréer le Navigator et perdre la page en cours).
        return Stack(
          children: [
            Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: actif == null
                      ? const SizedBox(width: double.infinity)
                      : BarreAppelEnCours(appel: actif),
                ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: actif != null,
                    child: child,
                  ),
                ),
              ],
            ),
            if (sonne != null)
              Positioned.fill(child: AppelEntrantScreen(appel: sonne)),
          ],
        );
      },
    );
  }
}

/// Bandeau sombre en haut pendant un appel, avec chrono et « Raccrocher ».
class BarreAppelEnCours extends StatefulWidget {
  const BarreAppelEnCours({super.key, required this.appel});

  final AppelActif appel;

  @override
  State<BarreAppelEnCours> createState() => _BarreAppelEnCoursState();
}

class _BarreAppelEnCoursState extends State<BarreAppelEnCours> {
  late final Timer _horloge;

  @override
  void initState() {
    super.initState();
    // Rafraîchit le chronomètre chaque seconde.
    _horloge =
        Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _horloge.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appel = widget.appel;
    final nom = Services.contactDe(appel.numero)?.nom ?? appel.numero;
    final enCommunication = appel.phase == PhaseAppel.enCommunication;
    final debut = appel.debutCommunication;

    return Material(
      color: Couleurs.encre,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 14, 10),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: enCommunication ? Couleurs.vert : Couleurs.ambre,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      enCommunication
                          ? 'En communication · $nom'
                          : 'Appel vers $nom…',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      debut != null
                          ? chrono(DateTime.now().difference(debut))
                          : 'Ça sonne…',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontFeatures: chiffresFixes,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: Services.etat.raccrocher,
                style: FilledButton.styleFrom(
                  backgroundColor: Couleurs.rouge,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.call_end_rounded, size: 18),
                label: const Text('Raccrocher'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

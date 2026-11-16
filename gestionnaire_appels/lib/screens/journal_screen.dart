import 'package:flutter/material.dart';

import '../models/modeles.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/en_tete_page.dart';
import '../widgets/fiche_contact.dart';
import '../widgets/formats.dart';
import '../widgets/ligne_journal.dart';
import 'clavier_screen.dart';
import 'contact_detail_screen.dart';

enum _Filtre { tous, manques, filtres, emis }

/// Page d'accueil : le journal d'appels, groupé par jour.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  _Filtre _filtre = _Filtre.tous;

  bool _garder(Appel a) => switch (_filtre) {
        _Filtre.tous => true,
        _Filtre.manques => a.issue == IssueAppel.manque,
        _Filtre.filtres => presenter(a).filtre,
        _Filtre.emis => a.sens == SensAppel.sortant,
      };

  static const _libellesFiltres = {
    _Filtre.tous: 'Tous',
    _Filtre.manques: 'Manqués',
    _Filtre.filtres: 'Filtrés',
    _Filtre.emis: 'Émis',
  };

  void _ouvrirClavier() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Couleurs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ClavierScreen(
        onAppeler: (numero) {
          Navigator.pop(context);
          appelerDepuis(context, numero);
        },
      ),
    );
  }

  void _ouvrir(Appel appel) {
    if (estNumeroMasque(appel.numero)) return;
    final contact = Services.contactDe(appel.numero);
    if (contact == null) {
      ouvrirFicheContact(context, numero: appel.numero);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ContactDetailScreen(idContact: contact.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _ouvrirClavier,
        tooltip: 'Clavier',
        child: const Icon(Icons.dialpad_rounded),
      ),
      // On écoute aussi les contacts : un nom ajouté s'affiche tout de suite.
      body: StreamBuilder<List<Contact>>(
        stream: Services.contacts.surveiller(),
        builder: (context, _) => StreamBuilder<List<Appel>>(
          stream: Services.journal.surveiller(),
          builder: (context, snapshot) => _contenu(snapshot.data ?? const []),
        ),
      ),
    );
  }

  Widget _contenu(List<Appel> journal) {
    final maintenant = DateTime.now();
    final appels = [...journal]..sort((a, b) => b.debut.compareTo(a.debut));
    final aujourdhui =
        appels.where((a) => memeJour(a.debut, maintenant)).toList();
    final visibles = appels.where(_garder).toList();

    // Regroupement par jour (l'ordre d'insertion est conservé).
    final parJour = <String, List<Appel>>{};
    for (final a in visibles) {
      parJour.putIfAbsent(libelleJour(a.debut, maintenant), () => []).add(a);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        EnTetePage(
          titre: 'Appels',
          sousTitre:
              '${salutation(maintenant)} · ${capitaliser(dateLongue(maintenant))}',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _Compteur(
                  valeur: aujourdhui.length,
                  libelle: "Aujourd'hui",
                  icone: Icons.call_rounded,
                  couleur: Couleurs.encre,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Compteur(
                  valeur: aujourdhui
                      .where((a) => a.issue == IssueAppel.manque)
                      .length,
                  libelle: 'Manqués',
                  icone: Icons.call_missed_rounded,
                  couleur: Couleurs.rouge,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Compteur(
                  valeur: aujourdhui.where((a) => presenter(a).filtre).length,
                  libelle: 'Filtrés',
                  icone: Icons.auto_awesome_rounded,
                  couleur: Couleurs.signal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _Filtre.values)
                PuceFiltre(
                  libelle: _libellesFiltres[f]!,
                  actif: _filtre == f,
                  onTap: () => setState(() => _filtre = f),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (visibles.isEmpty)
          _EtatVide(filtreActif: _filtre != _Filtre.tous),
        for (final jour in parJour.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 10),
            child: Text(
              jour.key.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: Couleurs.texteDoux,
              ),
            ),
          ),
          for (final appel in jour.value)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LigneJournal(appel: appel, onTap: () => _ouvrir(appel)),
            ),
        ],
      ],
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.valeur,
    required this.libelle,
    required this.icone,
    required this.couleur,
  });

  final int valeur;
  final String libelle;
  final IconData icone;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Carte(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, size: 18, color: couleur),
          ),
          const SizedBox(height: 14),
          Text(
            '$valeur',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Couleurs.texte,
              fontFeatures: chiffresFixes,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(libelle,
              style: const TextStyle(fontSize: 12, color: Couleurs.texteDoux)),
        ],
      ),
    );
  }
}

class _EtatVide extends StatelessWidget {
  const _EtatVide({required this.filtreActif});

  final bool filtreActif;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 0),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Couleurs.surface,
              shape: BoxShape.circle,
              border: Border.all(color: Couleurs.trait),
            ),
            child: const Icon(Icons.call_outlined,
                size: 30, color: Couleurs.texteDoux),
          ),
          const SizedBox(height: 16),
          Text(
            filtreActif ? 'Aucun appel dans ce filtre' : 'Aucun appel pour le moment',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: Couleurs.texte),
          ),
          const SizedBox(height: 6),
          const Text(
            'Les appels reçus et émis, et ce que le moteur en a fait, '
            'apparaîtront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Couleurs.texteDoux),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/modeles.dart';
import '../services/services.dart';
import '../widgets/fiche_contact.dart';

/// Onglet « Téléphone » : connexion au serveur, appels, et décisions
/// prises par le moteur de règles pour chaque appel entrant.
/// Tout passe par Services (SipServiceUa + GestionnaireAppels).
class SipTestScreen extends StatefulWidget {
  const SipTestScreen({super.key});

  @override
  State<SipTestScreen> createState() => _SipTestScreenState();
}

class _SipTestScreenState extends State<SipTestScreen> {
  final _ipServeur = TextEditingController(
    text: Services.compteParDefaut.serveur,
  );
  final _utilisateur = TextEditingController(
    text: Services.compteParDefaut.utilisateur,
  );
  final _motDePasse = TextEditingController(
    text: Services.compteParDefaut.motDePasse,
  );
  final _destination = TextEditingController(text: '300');

  EtatConnexion _etat = Services.sipUa.etatActuel;

  /// Appel qui sonne (le moteur a décidé « sonner »).
  AppelEntrant? _sonne;

  /// Appel en communication (entrant décroché ou sortant).
  String? _appelEnCours;

  /// Décisions du moteur, la plus récente en premier.
  final List<(AppelEntrant, Decision, DateTime)> _decisions = [];

  final List<StreamSubscription<dynamic>> _abonnements = [];

  @override
  void initState() {
    super.initState();
    _abonnements.addAll([
      Services.sip.etatConnexion.listen((e) => setState(() => _etat = e)),
      Services.gestionnaire.appelsASonner.listen(
        (a) => setState(() => _sonne = a),
      ),
      Services.gestionnaire.decisions.listen(
        (d) =>
            setState(() => _decisions.insert(0, (d.$1, d.$2, DateTime.now()))),
      ),
      Services.sip.etatAppels.listen(_suivreEtat),
      Services.sipUa.messagesRecus.listen(
        (m) => _message('Message de ${m.$1} : ${m.$2}'),
      ),
    ]);
  }

  @override
  void dispose() {
    for (final a in _abonnements) {
      a.cancel();
    }
    for (final c in [_ipServeur, _utilisateur, _motDePasse, _destination]) {
      c.dispose();
    }
    super.dispose();
  }

  void _suivreEtat(EtatAppel etat) {
    setState(() {
      switch (etat.statut) {
        case StatutAppel.sonne:
          break;
        case StatutAppel.enCours:
          _appelEnCours = etat.idAppel;
          if (_sonne?.idAppel == etat.idAppel) _sonne = null;
        case StatutAppel.termine:
        case StatutAppel.echec:
          if (_sonne?.idAppel == etat.idAppel) _sonne = null;
          if (_appelEnCours == etat.idAppel) _appelEnCours = null;
      }
    });
  }

  // ---------------- Actions ----------------

  static const _idNePasDeranger = 'ne-pas-deranger';

  /// « Ne pas déranger » = une règle utilisateur « tous → messagerie ».
  /// Les favoris passent quand même (règle système, testée avant).
  Future<void> _basculerNePasDeranger(bool actif) async {
    if (actif) {
      await Services.regles.enregistrer(
        const Regle(
          id: _idNePasDeranger,
          nom: 'Ne pas déranger',
          priorite: 100,
          condition: ConditionRegle(),
          action: ActionRegle(type: TypeAction.messagerie),
        ),
      );
    } else {
      await Services.regles.supprimer(_idNePasDeranger);
    }
  }

  Future<void> _connecter() => Services.sip.connecter(
    CompteSip(
      serveur: _ipServeur.text.trim(),
      utilisateur: _utilisateur.text.trim(),
      motDePasse: _motDePasse.text,
      nomAffiche: Services.compteParDefaut.nomAffiche,
    ),
  );

  Future<void> _appeler() async {
    try {
      final id = await Services.gestionnaire.appeler(_destination.text.trim());
      setState(() => _appelEnCours = id);
    } catch (e) {
      _message('Appel impossible : $e');
    }
  }
  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  // ---------------- Réponse par message ----------------

  static const _messagesRapides = [
    'Je suis occupé, je vous rappelle plus tard.',
    'Je suis en réunion, je vous rappelle.',
    'Je ne peux pas répondre, écrivez-moi.',
  ];

  void _ouvrirVoletMessages(AppelEntrant appel) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Rejeter avec un message',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final msg in _messagesRapides)
              ListTile(
                leading: const Icon(Icons.message_outlined),
                title: Text(msg),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await Services.gestionnaire
                        .rejeterAvecMessage(appel.idAppel, msg);
                    _message('Message envoyé à ${appel.numero}');
                  } catch (e) {
                    _message('Envoi impossible : $e');
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Contact? _contactDe(String numero) {
    final n = normaliserNumero(numero);
    for (final c in Services.contacts.tous) {
      if (normaliserNumero(c.numero) == n) return c;
    }
    return null;
  }

  // ---------------- Interface ----------------

  @override
  Widget build(BuildContext context) {
    final titre = Theme.of(context).textTheme.titleMedium;
    final connecte = _etat == EtatConnexion.connecte;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Appel qui sonne ----
            if (_sonne != null) _carteAppelEntrant(_sonne!),
            if (_appelEnCours != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.phone_in_talk, color: Colors.green),
                  title: const Text('En communication'),
                  trailing: FilledButton.icon(
                    onPressed:
                        () => Services.gestionnaire.raccrocher(_appelEnCours!),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    icon: const Icon(Icons.call_end),
                    label: const Text('Raccrocher'),
                  ),
                ),
              ),

            // ---- Ne pas déranger ----
            StreamBuilder<List<Regle>>(
              stream: Services.regles.surveiller(),
              builder: (context, snapshot) {
                final actif = (snapshot.data ?? []).any(
                  (r) => r.id == _idNePasDeranger,
                );
                return SwitchListTile(
                  value: actif,
                  onChanged: _basculerNePasDeranger,
                  secondary: Icon(
                    actif ? Icons.do_not_disturb_on : Icons.do_not_disturb_off,
                  ),
                  title: const Text('Ne pas déranger'),
                  subtitle: const Text(
                    'Tous les appels vont sur la messagerie, sauf les favoris',
                  ),
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
            const Divider(height: 24),

            // ---- Connexion ----
            Text('Connexion au serveur', style: titre),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _ipServeur,
                    decoration: const InputDecoration(
                      labelText: 'IP serveur',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _utilisateur,
                    decoration: const InputDecoration(
                      labelText: 'Compte',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _motDePasse,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: connecte ? Services.sip.deconnecter : _connecter,
                  child: Text(connecte ? 'Se déconnecter' : 'Se connecter'),
                ),
                const SizedBox(width: 12),
                Text(switch (_etat) {
                  EtatConnexion.deconnecte => 'Déconnecté',
                  EtatConnexion.connexion => 'Connexion…',
                  EtatConnexion.connecte => 'Connecté ✅',
                  EtatConnexion.erreur => 'Erreur de connexion ❌',
                }),
              ],
            ),

            // ---- Appeler ----
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _destination,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Numéro (300 = Linphone, 100 = écho)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed:
                      connecte && _appelEnCours == null ? _appeler : null,
                  icon: const Icon(Icons.call),
                  label: const Text('Appeler'),
                ),
              ],
            ),

            // ---- Décisions du moteur ----
            const Divider(height: 32),
            Text('Appels reçus et décisions du moteur', style: titre),
            const SizedBox(height: 4),
            if (_decisions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Aucun appel reçu pour le moment.'),
              ),
            for (final (appel, decision, quand) in _decisions)
              _ligneDecision(appel, decision, quand),
          ],
        ),
      ),
    );
  }

  Widget _carteAppelEntrant(AppelEntrant appel) {
    final contact = _contactDe(appel.numero);
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Icon(Icons.ring_volume, size: 40),
            Text(
              contact?.nom ?? appel.nomAffiche ?? appel.numero,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(appel.numero),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      () => Services.gestionnaire.decrocher(appel.idAppel),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.call),
                  label: const Text('Décrocher'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Services.gestionnaire.rejeter(appel.idAppel),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.call_end),
                  label: const Text('Rejeter'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _ouvrirVoletMessages(appel),
                  icon: const Icon(Icons.message),
                  label: const Text('Message'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligneDecision(AppelEntrant appel, Decision decision, DateTime quand) {
    final contact = _contactDe(appel.numero);
    final (icone, couleur) = switch (decision.action.type) {
      TypeAction.sonner => (Icons.ring_volume, Colors.green),
      TypeAction.rejeter => (Icons.call_end, Colors.red),
      TypeAction.rediriger => (Icons.phone_forwarded, Colors.orange),
      TypeAction.messagerie => (Icons.voicemail, Colors.blue),
    };
    final heure =
        '${quand.hour.toString().padLeft(2, '0')}:'
        '${quand.minute.toString().padLeft(2, '0')}:'
        '${quand.second.toString().padLeft(2, '0')}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icone, color: couleur),
      title: Text(contact?.nom ?? appel.numero),
      subtitle: Text('$heure · ${decision.explication}'),
      trailing:
          appel.estMasque
              ? null
              : IconButton(
                tooltip:
                    contact == null
                        ? 'Enregistrer en contact'
                        : 'Modifier le contact',
                icon: Icon(contact == null ? Icons.person_add : Icons.edit),
                onPressed: () async {
                  await ouvrirFicheContact(
                    context,
                    existant: contact,
                    numero: appel.numero,
                  );
                  setState(() {}); // rafraîchit le nom affiché
                },
              ),
    );
  }
}

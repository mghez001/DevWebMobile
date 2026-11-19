import 'package:flutter/material.dart';

import '../models/modeles.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/en_tete_page.dart';
import '../widgets/formats.dart';
import '../widgets/ligne_journal.dart' show Avatar, appelerDepuis;

/// Onglet « Messages » : les messages texte SIP reçus, du plus récent au
/// plus ancien (ex. « Je suis en réunion… » quand quelqu'un a refusé
/// notre appel avec un message rapide).
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // On écoute aussi les contacts : un nom ajouté s'affiche tout de suite.
    return StreamBuilder<List<Contact>>(
      stream: Services.contacts.surveiller(),
      builder: (context, _) => StreamBuilder<List<MessageRecu>>(
        stream: Services.messages.surveiller(),
        builder: (context, snapshot) =>
            _contenu(context, snapshot.data ?? const []),
      ),
    );
  }

  Widget _contenu(BuildContext context, List<MessageRecu> liste) {
    final maintenant = DateTime.now();
    final messages = [...liste]..sort((a, b) => b.recuLe.compareTo(a.recuLe));

    final parJour = <String, List<MessageRecu>>{};
    for (final m in messages) {
      parJour.putIfAbsent(libelleJour(m.recuLe, maintenant), () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        EnTetePage(
          titre: 'Messages',
          sousTitre: messages.isEmpty
              ? 'Messages texte reçus'
              : '${messages.length} message${messages.length > 1 ? 's' : ''} reçu${messages.length > 1 ? 's' : ''}',
        ),
        if (messages.isEmpty) const _EtatVide(),
        for (final jour in parJour.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 10),
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
          for (final message in jour.value)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _LigneMessage(message: message),
            ),
        ],
      ],
    );
  }
}

/// Nom à afficher pour l'expéditeur : contact connu, sinon nom SIP,
/// sinon numéro.
String nomExpediteur(MessageRecu message) {
  final contact = Services.contactDe(message.numero);
  if (contact != null) return contact.nom;
  final nom = message.nomAffiche?.trim();
  if (nom != null && nom.isNotEmpty) return nom;
  return message.numero.isEmpty ? 'Inconnu' : message.numero;
}

class _LigneMessage extends StatelessWidget {
  const _LigneMessage({required this.message});

  final MessageRecu message;

  @override
  Widget build(BuildContext context) {
    final nom = nomExpediteur(message);
    final peutRappeler = !estNumeroMasque(message.numero);

    return Carte(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(nom: nom),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nom,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Couleurs.texte,
                        ),
                      ),
                    ),
                    Text(
                      heureMinute(message.recuLe),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Couleurs.texteDoux,
                        fontFeatures: chiffresFixes,
                      ),
                    ),
                  ],
                ),
                if (nom != message.numero && message.numero.isNotEmpty)
                  Text(
                    message.numero,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Couleurs.texteDoux,
                      fontFeatures: chiffresFixes,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  message.texte,
                  style: const TextStyle(color: Couleurs.texte, height: 1.35),
                ),
              ],
            ),
          ),
          if (peutRappeler)
            IconButton(
              onPressed: () => appelerDepuis(context, message.numero),
              tooltip: 'Rappeler',
              color: Couleurs.vert,
              icon: const Icon(Icons.call_rounded),
            ),
        ],
      ),
    );
  }
}

class _EtatVide extends StatelessWidget {
  const _EtatVide();

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
            child: const Icon(Icons.sms_outlined,
                size: 30, color: Couleurs.texteDoux),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun message pour le moment',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: Couleurs.texte),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quand quelqu’un refuse votre appel avec un message rapide, '
            'son message apparaîtra ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Couleurs.texteDoux),
          ),
        ],
      ),
    );
  }
}

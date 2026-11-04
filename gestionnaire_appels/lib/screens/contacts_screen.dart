import 'package:flutter/material.dart';

import '../data/fausses_donnees.dart';

/// Liste des contacts.
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: fauxContacts.length,
      itemBuilder: (context, i) {
        final contact = fauxContacts[i];
        return ListTile(
          leading: CircleAvatar(child: Text(contact.nom[0])),
          title: Text(contact.nom),
          subtitle: Text(contact.numero),
          trailing: IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              // Pour l'instant on affiche juste un message.
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Appel de ${contact.nom}…')),
              );
            },
          ),
        );
      },
    );
  }
}


import 'package:flutter_contacts/flutter_contacts.dart';

class ContactsService {

  Future<String?> chercherContact(String numero) async {

    // Demander l'autorisation
    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    if (permission != PermissionStatus.granted) {
      return null;
    }

    // Récupérer les contacts du téléphone
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );

    // Chercher le numéro
    for (final contact in contacts) {
      for (final telephone in contact.phones) {
        if (telephone.number == numero) {
          return contact.displayName;
        }
      }
    }

    // Aucun contact trouvé
    return null;
  }
}

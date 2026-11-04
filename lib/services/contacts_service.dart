import 'package:flutter_contacts/flutter_contacts.dart';

class ContactsService {

  Future<String?> chercherContact(String numero) async {

    //  Demander la permission
    if (!await FlutterContacts.requestPermission()) {
      return null;
    }

    //  Récupérer les vrais contacts du téléphone
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
    );

    //  Rechercher le numéro
    for (final contact in contacts) {
      for (final telephone in contact.phones) {
        if (telephone.number == numero) {
          return contact.displayName;
        }
      }
    }

    //  Contact inconnu
    return null;
  }
}

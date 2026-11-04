import '../models/appel.dart';

/// Fausses données pour construire l'interface.
/// Plus tard, elles seront remplacées par le vrai journal du téléphone.
final List<Appel> fauxAppels = [
  Appel(
    nom: 'Maman',
    numero: '06 12 34 56 78',
    type: TypeAppel.entrant,
    date: DateTime.now().subtract(const Duration(minutes: 20)),
    duree: const Duration(minutes: 12, seconds: 4),
  ),
  Appel(
    nom: 'Inconnu',
    numero: '01 98 76 54 32',
    type: TypeAppel.manque,
    date: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  Appel(
    nom: 'Lucas',
    numero: '07 11 22 33 44',
    type: TypeAppel.sortant,
    date: DateTime.now().subtract(const Duration(days: 1)),
    duree: const Duration(minutes: 3, seconds: 45),
  ),
  Appel(
    nom: 'Cabinet médical',
    numero: '04 55 66 77 88',
    type: TypeAppel.entrant,
    date: DateTime.now().subtract(const Duration(days: 2)),
    duree: const Duration(minutes: 1, seconds: 10),
  ),
];

const List<Contact> fauxContacts = [
  Contact(nom: 'Cabinet médical', numero: '04 55 66 77 88'),
  Contact(nom: 'Lucas', numero: '07 11 22 33 44'),
  Contact(nom: 'Maman', numero: '06 12 34 56 78'),
  Contact(nom: 'Sarah', numero: '06 99 88 77 66'),
];

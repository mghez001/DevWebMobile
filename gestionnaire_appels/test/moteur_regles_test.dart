import 'package:flutter_test/flutter_test.dart';
import 'package:gestionnaire_appels/models/modeles.dart';
import 'package:gestionnaire_appels/services/moteur_regles.dart';

/// Tests du moteur de règles.
/// Lancer : flutter test test/moteur_regles_test.dart
///
/// Les tests marqués `skip` décrivent le comportement attendu des TODO :
/// quand vous implémentez une fonction, enlevez le `skip` du test
/// correspondant (et ajoutez-en d'autres !).
void main() {
  const moteur = MoteurDeRegles();

  // --- Données de test ------------------------------------------------
  const lucas = Contact(
      id: 'c1', nom: 'Lucas', numero: '300', groupes: {GroupeContact.pro});
  const maman = Contact(
      id: 'c2', nom: 'Maman', numero: '301', groupes: {GroupeContact.favori});
  const spammeur = Contact(
      id: 'c3', nom: 'Spam', numero: '999', groupes: {GroupeContact.bloque});

  AppelEntrant appelDe(String numero) => AppelEntrant(
      idAppel: 'id-$numero', numero: numero, recuLe: DateTime(2026, 11, 12, 14));

  final mercredi14h = DateTime(2026, 11, 12, 14, 0); // un mercredi
  final mercredi23h = DateTime(2026, 11, 12, 23, 0);

  const inconnusMessagerie = Regle(
    id: 'r1',
    nom: 'Inconnus vers la messagerie',
    priorite: 10,
    condition: ConditionRegle(appelant: TypeAppelant.inconnus),
    action: ActionRegle(
        type: TypeAction.messagerie, messageTexte: 'Laissez-moi un message'),
  );

  const nuit = Regle(
    id: 'r2',
    nom: 'Nuit',
    priorite: 20,
    condition: ConditionRegle(plage: PlageHoraire(Heure(22, 0), Heure(8, 0))),
    action: ActionRegle(type: TypeAction.messagerie),
  );

  // --- Déjà fonctionnels ----------------------------------------------

  test('sans règle : sonnerie normale', () {
    final d = moteur.decider(
        appelDe('300'), ContexteDecision(maintenant: mercredi14h));
    expect(d.action.type, TypeAction.sonner);
    expect(d.regle, isNull);
  });

  test('règle « tous » : la plus petite priorité gagne', () {
    const rejetTous = Regle(
        id: 'a', nom: 'Rejet', priorite: 5,
        condition: ConditionRegle(),
        action: ActionRegle(type: TypeAction.rejeter));
    const messagerieTous = Regle(
        id: 'b', nom: 'Messagerie', priorite: 1,
        condition: ConditionRegle(),
        action: ActionRegle(type: TypeAction.messagerie));
    final d = moteur.decider(
      appelDe('300'),
      ContexteDecision(
          maintenant: mercredi14h, regles: [rejetTous, messagerieTous]),
    );
    expect(d.regle?.nom, 'Messagerie');
  });

  test('une règle désactivée est ignorée', () {
    final d = moteur.decider(
      appelDe('300'),
      ContexteDecision(maintenant: mercredi14h, regles: [
        const Regle(
            id: 'a', nom: 'Off', priorite: 1, active: false,
            condition: ConditionRegle(),
            action: ActionRegle(type: TypeAction.rejeter)),
      ]),
    );
    expect(d.action.type, TypeAction.sonner);
  });

  test('normaliserNumero', () {
    expect(normaliserNumero('sip:300@127.0.0.1'), '300');
    expect(normaliserNumero('06 12.34-56'), '06123456');
  });

  test('PlageHoraire passe minuit', () {
    const p = PlageHoraire(Heure(22, 0), Heure(8, 0));
    expect(p.contient(mercredi23h), isTrue);
    expect(p.contient(DateTime(2026, 11, 13, 7, 59)), isTrue);
    expect(p.contient(mercredi14h), isFalse);
  });

  // --- À faire passer (enlever le skip une fois implémenté) ------------

  test('inconnu → messagerie', () {
    final d = moteur.decider(
      appelDe('555'),
      ContexteDecision(
          maintenant: mercredi14h,
          contacts: [lucas, maman],
          regles: [inconnusMessagerie]),
    );
    expect(d.action.type, TypeAction.messagerie);
  }, skip: 'appelantCorrespond : cas inconnus');

  test('contact connu → sonne malgré la règle « inconnus »', () {
    final d = moteur.decider(
      appelDe('300'),
      ContexteDecision(
          maintenant: mercredi14h,
          contacts: [lucas],
          regles: [inconnusMessagerie]),
    );
    expect(d.action.type, TypeAction.sonner);
  });

  test('liste noire → rejet', () {
    final d = moteur.decider(
      appelDe('999'),
      ContexteDecision(maintenant: mercredi14h, contacts: [spammeur]),
    );
    expect(d.action.type, TypeAction.rejeter);
  }, skip: 'reglesSysteme : liste noire');

  test('nuit → messagerie à 23h, sonne à 14h', () {
    final ctx23h = ContexteDecision(maintenant: mercredi23h, regles: [nuit]);
    final ctx14h = ContexteDecision(maintenant: mercredi14h, regles: [nuit]);
    expect(moteur.decider(appelDe('300'), ctx23h).action.type,
        TypeAction.messagerie);
    expect(moteur.decider(appelDe('300'), ctx14h).action.type,
        TypeAction.sonner);
  }, skip: 'plageCorrespond');

  test('en réunion → messagerie avec heure de fin', () {
    final reunion = EvenementCalendrier(
        id: 'e1', titre: 'Réunion',
        debut: DateTime(2026, 11, 12, 13, 30),
        fin: DateTime(2026, 11, 12, 15, 30));
    const enReunion = Regle(
      id: 'r3', nom: 'En réunion', priorite: 5,
      condition: ConditionRegle(siCalendrierOccupe: true),
      action: ActionRegle(
          type: TypeAction.messagerie,
          messageTexte: 'En réunion jusqu\'à {fin}'),
    );
    final d = moteur.decider(
      appelDe('300'),
      ContexteDecision(
          maintenant: mercredi14h, evenements: [reunion], regles: [enReunion]),
    );
    expect(d.action.type, TypeAction.messagerie);
    expect(d.action.messageTexte, 'En réunion jusqu\'à 15:30');
  }, skip: 'calendrierCorrespond + resoudreTexte');

  test('appel répété dans les 3 min → sonne (urgence)', () {
    const urgence = Regle(
      id: 'r4', nom: 'Appel répété', priorite: 1,
      condition: ConditionRegle(appelRepeteDans: Duration(minutes: 3)),
      action: ActionRegle(type: TypeAction.sonner),
    );
    final d = moteur.decider(
      appelDe('555'),
      ContexteDecision(
        maintenant: mercredi23h,
        regles: [urgence, nuit],
        historique: [
          Appel(
              id: 'h1', sens: SensAppel.entrant, numero: '555',
              debut: mercredi23h.subtract(const Duration(minutes: 2)),
              issue: IssueAppel.messagerie),
        ],
      ),
    );
    expect(d.regle?.nom, 'Appel répété');
  }, skip: 'appelRepeteCorrespond');
}

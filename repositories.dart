import 'dart:async';

import '../models/modeles.dart';

/// =====================================================================
///  Repositories — où sont stockées les données.
///
///  Pour l'instant : versions EN MÉMOIRE (marchent aussi dans Chrome).
///  Plus tard : versions persistantes (ex. sqflite sur Android) qui
///  implémentent les mêmes interfaces → rien d'autre à changer.
/// =====================================================================

abstract class ContactRepository {
  List<Contact> get tous;
  Stream<List<Contact>> surveiller();
  Future<void> enregistrer(Contact contact); // ajoute ou remplace (même id)
  Future<void> supprimer(String id);
}

abstract class RegleRepository {
  List<Regle> get tous;
  Stream<List<Regle>> surveiller();
  Future<void> enregistrer(Regle regle);
  Future<void> supprimer(String id);
}

abstract class CalendrierRepository {
  List<EvenementCalendrier> get tous;
  Stream<List<EvenementCalendrier>> surveiller();
  Future<void> enregistrer(EvenementCalendrier evenement);
  Future<void> supprimer(String id);
}

abstract class JournalRepository {
  List<Appel> get tous;
  Stream<List<Appel>> surveiller();
  Future<void> ajouter(Appel appel);
}

// =====================================================================
//  Implémentations en mémoire
// =====================================================================

class _ListeEnMemoire<T> {
  _ListeEnMemoire(this._idDe, List<T> initiaux) : _elements = [...initiaux];

  final String Function(T) _idDe;
  final List<T> _elements;
  final _flux = StreamController<List<T>>.broadcast();

  List<T> get tous => List.unmodifiable(_elements);

  Stream<List<T>> surveiller() async* {
    yield tous; // valeur actuelle tout de suite
    yield* _flux.stream; // puis chaque modification
  }

  void enregistrer(T element) {
    final i = _elements.indexWhere((e) => _idDe(e) == _idDe(element));
    if (i == -1) {
      _elements.add(element);
    } else {
      _elements[i] = element;
    }
    _flux.add(tous);
  }

  void supprimer(String id) {
    _elements.removeWhere((e) => _idDe(e) == id);
    _flux.add(tous);
  }
}

class ContactRepositoryMemoire implements ContactRepository {
  ContactRepositoryMemoire([List<Contact> initiaux = const []])
      : _liste = _ListeEnMemoire<Contact>((c) => c.id, initiaux);
  final _ListeEnMemoire<Contact> _liste;

  @override
  List<Contact> get tous => _liste.tous;
  @override
  Stream<List<Contact>> surveiller() => _liste.surveiller();
  @override
  Future<void> enregistrer(Contact contact) async => _liste.enregistrer(contact);
  @override
  Future<void> supprimer(String id) async => _liste.supprimer(id);
}

class RegleRepositoryMemoire implements RegleRepository {
  RegleRepositoryMemoire([List<Regle> initiaux = const []])
      : _liste = _ListeEnMemoire<Regle>((r) => r.id, initiaux);
  final _ListeEnMemoire<Regle> _liste;

  @override
  List<Regle> get tous => _liste.tous;
  @override
  Stream<List<Regle>> surveiller() => _liste.surveiller();
  @override
  Future<void> enregistrer(Regle regle) async => _liste.enregistrer(regle);
  @override
  Future<void> supprimer(String id) async => _liste.supprimer(id);
}

class CalendrierRepositoryMemoire implements CalendrierRepository {
  CalendrierRepositoryMemoire([List<EvenementCalendrier> initiaux = const []])
      : _liste = _ListeEnMemoire<EvenementCalendrier>((e) => e.id, initiaux);
  final _ListeEnMemoire<EvenementCalendrier> _liste;

  @override
  List<EvenementCalendrier> get tous => _liste.tous;
  @override
  Stream<List<EvenementCalendrier>> surveiller() => _liste.surveiller();
  @override
  Future<void> enregistrer(EvenementCalendrier evenement) async =>
      _liste.enregistrer(evenement);
  @override
  Future<void> supprimer(String id) async => _liste.supprimer(id);
}

class JournalRepositoryMemoire implements JournalRepository {
  JournalRepositoryMemoire([List<Appel> initiaux = const []])
      : _liste = _ListeEnMemoire<Appel>((a) => a.id, initiaux);
  final _ListeEnMemoire<Appel> _liste;

  @override
  List<Appel> get tous => _liste.tous;
  @override
  Stream<List<Appel>> surveiller() => _liste.surveiller();
  @override
  Future<void> ajouter(Appel appel) async => _liste.enregistrer(appel);
}

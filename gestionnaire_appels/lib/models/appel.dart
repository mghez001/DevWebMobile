/// Les différents types d'appels possibles.
enum TypeAppel { entrant, sortant, manque }

/// Un appel du journal (modèle de données, sans aucune interface).
class Appel {
  final String nom;
  final String numero;
  final TypeAppel type;
  final DateTime date;
  final Duration duree;

  const Appel({
    required this.nom,
    required this.numero,
    required this.type,
    required this.date,
    this.duree = Duration.zero,
  });
}

/// Un contact du répertoire.
class Contact {
  final String nom;
  final String numero;

  const Contact({required this.nom, required this.numero});
}

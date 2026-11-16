/// Petits outils d'affichage (dates en français, durées, initiales).
library;

const _jours = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
];
const _mois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août',
  'septembre', 'octobre', 'novembre', 'décembre',
];

String deuxChiffres(int n) => n.toString().padLeft(2, '0');

String heureMinute(DateTime t) => '${deuxChiffres(t.hour)}:${deuxChiffres(t.minute)}';

String capitaliser(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// « lundi 16 novembre »
String dateLongue(DateTime t) =>
    '${_jours[t.weekday - 1]} ${t.day} ${_mois[t.month - 1]}';

bool memeJour(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// « Aujourd'hui », « Hier » ou « Lundi 9 novembre ».
String libelleJour(DateTime jour, DateTime maintenant) {
  final a = DateTime.utc(jour.year, jour.month, jour.day);
  final b = DateTime.utc(maintenant.year, maintenant.month, maintenant.day);
  final ecart = b.difference(a).inDays;
  if (ecart == 0) return "Aujourd'hui";
  if (ecart == 1) return 'Hier';
  return capitaliser(dateLongue(jour));
}

/// « 45 s », « 3 min », « 3 min 07 ».
String formaterDuree(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} s';
  final s = d.inSeconds % 60;
  return s == 0 ? '${d.inMinutes} min' : '${d.inMinutes} min ${deuxChiffres(s)}';
}

/// Chronomètre « 02:15 » (ou « 1:02:15 »).
String chrono(Duration d) {
  final h = d.inHours;
  final m = deuxChiffres(d.inMinutes % 60);
  final s = deuxChiffres(d.inSeconds % 60);
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String initiale(String nom) => nom.isEmpty ? '?' : nom[0].toUpperCase();

bool estNumeroMasque(String numero) =>
    numero.isEmpty || numero == 'anonymous' || numero == 'unknown';

String salutation(DateTime t) => t.hour < 18 ? 'Bonjour' : 'Bonsoir';

import 'package:flutter/material.dart';

import '../models/appel.dart';

/// Une ligne du journal d'appels (widget réutilisable).
class TuileAppel extends StatelessWidget {
  final Appel appel;

  const TuileAppel({super.key, required this.appel});

  IconData get _icone => switch (appel.type) {
        TypeAppel.entrant => Icons.call_received,
        TypeAppel.sortant => Icons.call_made,
        TypeAppel.manque => Icons.call_missed,
      };

  Color get _couleur => switch (appel.type) {
        TypeAppel.entrant => Colors.blue,
        TypeAppel.sortant => Colors.green,
        TypeAppel.manque => Colors.red,
      };

  String get _quand {
    final d = appel.date;
    final ecart = DateTime.now().difference(d);
    if (ecart.inMinutes < 60) return 'il y a ${ecart.inMinutes} min';
    if (ecart.inHours < 24) return 'il y a ${ecart.inHours} h';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  String get _duree {
    if (appel.duree == Duration.zero) return '';
    final m = appel.duree.inMinutes;
    final s = appel.duree.inSeconds % 60;
    return ' · ${m}min ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_icone, color: _couleur),
      title: Text(
        appel.nom,
        style: TextStyle(
          color: appel.type == TypeAppel.manque ? Colors.red : null,
        ),
      ),
      subtitle: Text('${appel.numero}\n$_quand$_duree'),
      isThreeLine: true,
      trailing: IconButton(
        icon: const Icon(Icons.call),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rappel de ${appel.nom}…')),
          );
        },
      ),
    );
  }
}

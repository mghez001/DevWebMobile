import 'package:flutter/material.dart';

import '../data/fausses_donnees.dart';
import '../widgets/tuile_appel.dart';

/// Liste des derniers appels.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (fauxAppels.isEmpty) {
      return const Center(child: Text('Aucun appel'));
    }
    return ListView.separated(
      itemCount: fauxAppels.length,
      separatorBuilder: (context, i) => const Divider(height: 1),
      itemBuilder: (context, i) => TuileAppel(appel: fauxAppels[i]),
    );
  }
}

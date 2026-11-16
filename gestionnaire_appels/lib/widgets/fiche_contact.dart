import 'package:flutter/material.dart';

import '../models/modeles.dart';
import '../services/services.dart';

/// Libellé, explication et icône de chaque groupe (cases à cocher).
const groupesAffiches = <GroupeContact, (String, String, IconData)>{
  GroupeContact.favori: (
    'Favori',
    'Sonne toujours, quelles que soient les règles',
    Icons.star
  ),
  GroupeContact.bloque: (
    'Bloqué / spam',
    'Tombe directement sur la messagerie',
    Icons.block
  ),
  GroupeContact.pro: ('Pro', 'Contact professionnel', Icons.work),
  GroupeContact.perso: ('Perso', 'Contact personnel', Icons.home),
};

/// Ouvre la fiche d'un contact (création ou modification) et l'enregistre.
///  - [existant] : contact à modifier (null = nouveau contact)
///  - [numero]   : numéro pré-rempli (ex. depuis un appel reçu)
Future<void> ouvrirFicheContact(BuildContext context,
    {Contact? existant, String? numero}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _FicheContact(existant: existant, numero: numero),
  );
}

class _FicheContact extends StatefulWidget {
  const _FicheContact({this.existant, this.numero});

  final Contact? existant;
  final String? numero;

  @override
  State<_FicheContact> createState() => _FicheContactState();
}

class _FicheContactState extends State<_FicheContact> {
  late final _nom = TextEditingController(text: widget.existant?.nom ?? '');
  late final _numero = TextEditingController(
      text: widget.existant?.numero ?? widget.numero ?? '');
  late final Set<GroupeContact> _groupes = {...?widget.existant?.groupes};

  @override
  void dispose() {
    _nom.dispose();
    _numero.dispose();
    super.dispose();
  }

  void _basculer(GroupeContact groupe, bool coche) {
    setState(() {
      if (coche) {
        _groupes.add(groupe);
        // Favori et bloqué sont incompatibles.
        if (groupe == GroupeContact.favori) _groupes.remove(GroupeContact.bloque);
        if (groupe == GroupeContact.bloque) _groupes.remove(GroupeContact.favori);
      } else {
        _groupes.remove(groupe);
      }
    });
  }

  Future<void> _enregistrer() async {
    final numero = normaliserNumero(_numero.text);
    if (numero.isEmpty) return;
    final nom = _nom.text.trim().isEmpty ? numero : _nom.text.trim();
    final id = widget.existant?.id ??
        'c-${DateTime.now().microsecondsSinceEpoch}';
    await Services.contacts.enregistrer(
      Contact(id: id, nom: nom, numero: numero, groupes: {..._groupes}),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _supprimer() async {
    await Services.contacts.supprimer(widget.existant!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existant == null ? 'Nouveau contact' : 'Modifier'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nom,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              TextField(
                controller: _numero,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Numéro (ex. 300)'),
              ),
              const SizedBox(height: 12),
              for (final MapEntry(key: groupe, value: (libelle, aide, icone))
                  in groupesAffiches.entries)
                CheckboxListTile(
                  value: _groupes.contains(groupe),
                  onChanged: (v) => _basculer(groupe, v ?? false),
                  secondary: Icon(icone),
                  title: Text(libelle),
                  subtitle: Text(aide),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existant != null)
          TextButton(
            onPressed: _supprimer,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _enregistrer, child: const Text('Enregistrer')),
      ],
    );
  }
}

/// Petites pastilles des groupes d'un contact.
class PastillesGroupes extends StatelessWidget {
  const PastillesGroupes(this.groupes, {super.key});

  final Set<GroupeContact> groupes;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        for (final g in groupes)
          Chip(
            avatar: Icon(groupesAffiches[g]!.$3, size: 16),
            label: Text(groupesAffiches[g]!.$1),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}

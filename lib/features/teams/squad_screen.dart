import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/id_generator.dart';
import '../../data/database/seed.dart';
import '../../data/models/player.dart';
import '../../logic/providers.dart';

/// Kader-Verwaltung für die feste Mannschaft SC Freising.
class SquadScreen extends ConsumerStatefulWidget {
  const SquadScreen({super.key});

  static const routeName = '/squad';

  @override
  ConsumerState<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends ConsumerState<SquadScreen> {
  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(teamsProvider);
    final team = ref.watch(scfTeamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kader'),
        actions: [
          IconButton(
            tooltip: 'Spieler hinzufügen',
            onPressed: () => _openPlayerEditor(context, null),
            icon: const Icon(Icons.person_add_alt),
          ),
        ],
      ),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Fehler: $error')),
        data: (_) {
          final players = [...team.players]
            ..sort((a, b) => a.number.compareTo(b.number));

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TeamBanner(playerCount: players.length),
                  const SizedBox(height: 16),
                  if (players.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.groups_outlined,
                              size: 40,
                              color: ScfColors.textFaint,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Noch keine Spieler im Kader.',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Füge Vorname, Nachname, Nummer und Position hinzu.',
                              textAlign: TextAlign.center,
                              style: ScfText.caption,
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () => _openPlayerEditor(context, null),
                              icon: const Icon(Icons.person_add_alt),
                              label: const Text('Ersten Spieler anlegen'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final player in players)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PlayerRow(
                          player: player,
                          onEdit: () => _openPlayerEditor(context, player),
                          onDelete: () => _confirmDelete(context, player),
                        ),
                      ),
                  const SizedBox(height: 12),
                  Text(
                    'Änderungen wirken sofort auf Live-Spiel und Statistiken.',
                    style: ScfText.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPlayerEditor(context, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Spieler'),
      ),
    );
  }

  Future<void> _openPlayerEditor(BuildContext context, Player? player) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _PlayerEditorDialog(player: player),
    );
  }

  void _confirmDelete(BuildContext context, Player player) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${player.fullName} löschen?'),
        content: const Text(
          'Der Spieler wird aus dem Kader entfernt. '
          'Vorhandene Spielstatistiken bleiben erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ScfColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final team = ref.read(scfTeamProvider);
              final players = [...team.players]
                ..removeWhere((p) => p.id == player.id);
              await ref
                  .read(teamRepositoryProvider)
                  .save(team.copyWith(players: players));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}

class _TeamBanner extends StatelessWidget {
  const _TeamBanner({required this.playerCount});

  final int playerCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF132337), Color(0xFF0B121C)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ScfColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: ScfColors.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text(
              'SC',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  scfTeamName,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$playerCount ${playerCount == 1 ? 'Spieler' : 'Spieler'} im Kader',
                  style: ScfText.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.verified, color: ScfColors.accent, size: 20),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.onEdit,
    required this.onDelete,
  });

  final Player player;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isKeeper = player.position == PlayerPosition.torwart;
    final accent = isKeeper ? ScfColors.cyan : ScfColors.accent;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.18),
          child: Text(
            '${player.number}',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        title: Text(
          player.fullName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          isKeeper ? 'Torwart' : 'Feldspieler',
          style: ScfText.caption.copyWith(fontSize: 11.5),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Bearbeiten',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'Löschen',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: ScfColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerEditorDialog extends ConsumerStatefulWidget {
  const _PlayerEditorDialog({required this.player});

  final Player? player;

  @override
  ConsumerState<_PlayerEditorDialog> createState() =>
      _PlayerEditorDialogState();
}

class _PlayerEditorDialogState extends ConsumerState<_PlayerEditorDialog> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _numberController;
  late PlayerPosition _position;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.player?.firstName ?? '');
    _lastNameController =
        TextEditingController(text: widget.player?.lastName ?? '');
    _numberController = TextEditingController(
      text: widget.player == null ? '' : '${widget.player!.number}',
    );
    _position = widget.player?.position ?? PlayerPosition.feldspieler;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.player != null;

    return AlertDialog(
      title: Text(isEdit ? 'Spieler bearbeiten' : 'Spieler hinzufügen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _firstNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Vorname'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _lastNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nachname'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(labelText: 'Trikotnummer'),
            ),
            const SizedBox(height: 10),
            SegmentedButton<PlayerPosition>(
              segments: const [
                ButtonSegment(
                  value: PlayerPosition.feldspieler,
                  label: Text('Feld'),
                ),
                ButtonSegment(
                  value: PlayerPosition.torwart,
                  label: Text('Torwart'),
                ),
              ],
              selected: {_position},
              onSelectionChanged: (selection) =>
                  setState(() => _position = selection.first),
              showSelectedIcon: false,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEdit ? 'Speichern' : 'Hinzufügen'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final number = int.tryParse(_numberController.text.trim());

    if (firstName.isEmpty || number == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte Vorname und Trikotnummer angeben.'),
        ),
      );
      return;
    }

    final team = ref.read(scfTeamProvider);
    final repository = ref.read(teamRepositoryProvider);
    final existing = widget.player;

    final List<Player> players;
    if (existing != null) {
      final updated = existing.copyWith(
        firstName: firstName,
        lastName: lastName,
        number: number,
        position: _position,
      );
      players = [
        for (final p in team.players)
          if (p.id == existing.id) updated else p,
      ];
    } else {
      players = [
        ...team.players,
        Player(
          id: newId(),
          number: number,
          firstName: firstName,
          lastName: lastName,
          position: _position,
        ),
      ];
    }
    await repository.save(team.copyWith(players: players));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

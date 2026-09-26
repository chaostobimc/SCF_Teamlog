import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/player.dart';
import '../../data/models/team.dart';
import '../../logic/providers.dart';

class TeamEditArgs {
  const TeamEditArgs({this.team});

  final Team? team;
}

/// Team anlegen oder bearbeiten: Name, Trikotfarben, Spielerkader.
class TeamEditScreen extends ConsumerStatefulWidget {
  const TeamEditScreen({super.key, this.existing});

  final Team? existing;

  @override
  ConsumerState<TeamEditScreen> createState() => _TeamEditScreenState();
}

class _TeamEditScreenState extends ConsumerState<TeamEditScreen> {
  late final TextEditingController _nameController;
  late List<Player> _players;
  late Color _primary;
  late Color _secondary;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _players = [...?existing?.players];
    _players.sort((a, b) => a.number.compareTo(b.number));
    _primary = existing?.primaryColor ?? ScfColors.accent;
    _secondary = existing?.secondaryColor ?? ScfColors.surface;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Teamnamen eingeben.')),
      );
      return;
    }
    final repository = ref.read(teamRepositoryProvider);
    final existing = widget.existing;
    final team = existing == null
        ? Team(
            id: newId(),
            name: name,
            players: _players,
            primaryColor: _primary,
            secondaryColor: _secondary,
          )
        : existing.copyWith(
            name: name,
            players: _players,
            primaryColor: _primary,
            secondaryColor: _secondary,
          );
    await repository.save(team);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteTeam() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Team löschen?'),
        content: Text('${existing.name} wird dauerhaft entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ScfColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(teamRepositoryProvider).delete(existing.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _editPlayer({Player? player}) async {
    final result = await showDialog<Player>(
      context: context,
      builder: (context) => _PlayerDialog(player: player),
    );
    if (result == null) return;
    setState(() {
      _players.removeWhere((p) => p.id == result.id);
      _players.add(result);
      _players.sort((a, b) => a.number.compareTo(b.number));
    });
  }

  void _removePlayer(Player player) {
    setState(() => _players.removeWhere((p) => p.id == player.id));
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Neues Team' : 'Team bearbeiten'),
        actions: [
          if (!isNew)
            IconButton(
              tooltip: 'Team löschen',
              onPressed: _deleteTeam,
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(
            tooltip: 'Speichern',
            onPressed: _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final details = _TeamDetails(
            nameController: _nameController,
            primary: _primary,
            secondary: _secondary,
            onPrimaryChanged: (color) => setState(() => _primary = color),
            onSecondaryChanged: (color) => setState(() => _secondary = color),
          );
          final squad = _SquadList(
            players: _players,
            onEdit: _editPlayer,
            onRemove: _removePlayer,
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: details),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: squad),
                    ],
                  )
                : ListView(
                    children: [
                      details,
                      const SizedBox(height: 16),
                      squad,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _TeamDetails extends StatelessWidget {
  const _TeamDetails({
    required this.nameController,
    required this.primary,
    required this.secondary,
    required this.onPrimaryChanged,
    required this.onSecondaryChanged,
  });

  final TextEditingController nameController;
  final Color primary;
  final Color secondary;
  final ValueChanged<Color> onPrimaryChanged;
  final ValueChanged<Color> onSecondaryChanged;

  static const List<Color> _palette = [
    Color(0xFFFF7A2F),
    Color(0xFFE04B4B),
    Color(0xFF3DBE64),
    Color(0xFF3E8EC4),
    Color(0xFFE8B93C),
    Color(0xFF9B59B6),
    Color(0xFF16A085),
    Color(0xFFB0BEC5),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Teamdaten',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Teamname'),
            ),
            const SizedBox(height: 18),
            const Text(
              'Trikotfarben',
              style: TextStyle(color: ScfColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _ColorPickerRow(
                  label: 'Hauptfarbe',
                  selected: primary,
                  palette: _palette,
                  onChanged: onPrimaryChanged,
                ),
                const SizedBox(width: 20),
                _ColorPickerRow(
                  label: 'Zweitfarbe',
                  selected: secondary,
                  palette: _palette,
                  onChanged: onSecondaryChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPickerRow extends StatelessWidget {
  const _ColorPickerRow({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onChanged,
  });

  final String label;
  final Color selected;
  final List<Color> palette;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: ScfColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in palette)
              GestureDetector(
                onTap: () => onChanged(color),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected == color
                          ? ScfColors.textPrimary
                          : ScfColors.outline,
                      width: selected == color ? 2.5 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SquadList extends StatelessWidget {
  const _SquadList({
    required this.players,
    required this.onEdit,
    required this.onRemove,
  });

  final List<Player> players;
  final void Function({Player? player}) onEdit;
  final ValueChanged<Player> onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kader',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => onEdit(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Spieler'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (players.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Noch keine Spieler im Kader',
                    style: TextStyle(color: ScfColors.textSecondary),
                  ),
                ),
              )
            else
              for (final player in players)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: ScfColors.surfaceRaised,
                    child: Text(
                      '${player.number}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ScfColors.accent,
                      ),
                    ),
                  ),
                  title: Text(player.fullName),
                  subtitle: Text(
                    '${player.position.label}'
                    '${player.gameRole == PlayerGameRole.keine ? '' : ' · ${player.gameRole.label}'}',
                    style: const TextStyle(
                        color: ScfColors.textSecondary, fontSize: 12.5),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Bearbeiten',
                        onPressed: () => onEdit(player: player),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Entfernen',
                        onPressed: () => onRemove(player),
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 20, color: ScfColors.danger),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _PlayerDialog extends ConsumerStatefulWidget {
  const _PlayerDialog({this.player});

  final Player? player;

  @override
  ConsumerState<_PlayerDialog> createState() => _PlayerDialogState();
}

class _PlayerDialogState extends ConsumerState<_PlayerDialog> {
  late final TextEditingController _numberController;
  late final TextEditingController _firstController;
  late final TextEditingController _lastController;
  late PlayerPosition _position;
  late PlayerGameRole _role;

  @override
  void initState() {
    super.initState();
    final player = widget.player;
    _numberController =
        TextEditingController(text: player == null ? '' : '${player.number}');
    _firstController = TextEditingController(text: player?.firstName ?? '');
    _lastController = TextEditingController(text: player?.lastName ?? '');
    _position = player?.position ?? PlayerPosition.feldspieler;
    _role = player?.gameRole ?? PlayerGameRole.keine;
  }

  @override
  void dispose() {
    _numberController.dispose();
    _firstController.dispose();
    _lastController.dispose();
    super.dispose();
  }

  void _submit() {
    final number = int.tryParse(_numberController.text.trim());
    if (number == null || number < 1 || number > 99) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nummer zwischen 1 und 99 eingeben.')),
      );
      return;
    }
    final player = Player(
      id: widget.player?.id ?? newId(),
      number: number,
      firstName: _firstController.text.trim(),
      lastName: _lastController.text.trim(),
      position: _position,
      gameRole: _role,
    );
    Navigator.of(context).pop(player);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.player == null;

    return AlertDialog(
      title: Text(isNew ? 'Neuer Spieler' : 'Spieler bearbeiten'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Rückennummer'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstController,
                    decoration: const InputDecoration(labelText: 'Vorname'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lastController,
                    decoration: const InputDecoration(labelText: 'Nachname'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PlayerPosition>(
              initialValue: _position,
              decoration: const InputDecoration(labelText: 'Position'),
              items: [
                for (final position in PlayerPosition.values)
                  DropdownMenuItem(
                    value: position,
                    child: Text(position.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _position = value;
                    if (value == PlayerPosition.torwart) _role = PlayerGameRole.keine;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PlayerGameRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rolle im Spiel'),
              items: [
                for (final role in PlayerGameRole.values)
                  DropdownMenuItem(
                    value: role,
                    child: Text(role.label),
                  ),
              ],
              onChanged: _position == PlayerPosition.torwart
                  ? null
                  : (value) {
                      if (value != null) setState(() => _role = value);
                    },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

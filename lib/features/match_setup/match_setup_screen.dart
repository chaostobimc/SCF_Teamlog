import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/id_generator.dart';
import '../../data/database/seed.dart';
import '../../data/models/match.dart';
import '../../data/models/player.dart';
import '../../logic/providers.dart';
import '../../routing/app_router.dart';

/// Neues Spiel: Gegner, Rahmen, Spielzeit und Aufgebot – ohne Team-Auswahl,
/// denn die App ist fest auf SC Freising ausgelegt.
class MatchSetupScreen extends ConsumerStatefulWidget {
  const MatchSetupScreen({super.key});

  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  final _opponentController = TextEditingController();
  bool _isHome = true;
  int _halfLengthMin = 30;
  DateTime _date = DateTime.now();
  bool _preselected = false;
  final Set<String> _squad = <String>{};

  @override
  void dispose() {
    _opponentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(teamsProvider);
    final team = ref.watch(scfTeamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spiel anlegen')),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Fehler: $error')),
        data: (_) {
          final players = [...team.players]
            ..sort((a, b) => a.number.compareTo(b.number));
          if (!_preselected && players.isNotEmpty) {
            _preselected = true;
            _squad.addAll(players.map((p) => p.id));
          }
          final goalkeepers = players
              .where((p) => p.position == PlayerPosition.torwart)
              .toList();
          final fieldPlayers = players
              .where((p) => p.position == PlayerPosition.feldspieler)
              .toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('GEGNER & RAHMEN', style: ScfText.sectionLabel),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _opponentController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Gegner',
                      hintText: 'z. B. TSV Ottobrunn',
                      prefixIcon: Icon(Icons.shield_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.event_outlined, size: 18),
                          label: Text(_dateLabel()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              label: Text('Heim'),
                              icon: Icon(Icons.home_outlined),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text('Auswärts'),
                              icon: Icon(Icons.directions_bus_outlined),
                            ),
                          ],
                          selected: {_isHome},
                          onSelectionChanged: (selection) =>
                              setState(() => _isHome = selection.first),
                          showSelectedIcon: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('SPIELZEIT', style: ScfText.sectionLabel),
                  const SizedBox(height: 6),
                  Text(
                    'Halbzeitlänge – die Uhr läuft erst im Live-Spiel '
                    'und ist dort jederzeit anpassbar.',
                    style: ScfText.caption,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 20, label: Text('20 min')),
                      ButtonSegment(value: 25, label: Text('25 min')),
                      ButtonSegment(value: 30, label: Text('30 min')),
                      ButtonSegment(value: 35, label: Text('35 min')),
                    ],
                    selected: {_halfLengthMin},
                    onSelectionChanged: (selection) =>
                        setState(() => _halfLengthMin = selection.first),
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'AUFGEBOT · ${_squad.length}/${players.length}',
                    style: ScfText.sectionLabel,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nur ausgewählte Spieler erscheinen im Live-Spiel.',
                    style: ScfText.caption,
                  ),
                  const SizedBox(height: 10),
                  if (players.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'Noch keine Spieler im Kader.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () =>
                                  Navigator.of(context)
                                      .pushNamed(AppRoutes.squad),
                              icon: const Icon(Icons.people_outline),
                              label: const Text('Kader öffnen'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: goalkeepers.isEmpty
                                ? null
                                : () => _toggleGroup(goalkeepers),
                            icon: Icon(
                              _allSelected(goalkeepers)
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 18,
                            ),
                            label: Text('Torwart (${goalkeepers.length})'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: fieldPlayers.isEmpty
                                ? null
                                : () => _toggleGroup(fieldPlayers),
                            icon: Icon(
                              _allSelected(fieldPlayers)
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 18,
                            ),
                            label: Text('Feld (${fieldPlayers.length})'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _SquadGroup(
                      label: 'TOR',
                      players: goalkeepers,
                      selected: _squad,
                      onToggle: _toggle,
                    ),
                    const SizedBox(height: 10),
                    _SquadGroup(
                      label: 'FELD',
                      players: fieldPlayers,
                      selected: _squad,
                      onToggle: _toggle,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _squad.isEmpty ? null : _startMatch,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Spiel starten'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _dateLabel() {
    return '${_date.day.toString().padLeft(2, '0')}.'
        '${_date.month.toString().padLeft(2, '0')}.${_date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool _allSelected(List<Player> group) =>
      group.isNotEmpty && group.every((p) => _squad.contains(p.id));

  void _toggleGroup(List<Player> group) {
    setState(() {
      if (_allSelected(group)) {
        _squad.removeWhere((id) => group.any((p) => p.id == id));
      } else {
        _squad.addAll(group.map((p) => p.id));
      }
    });
  }

  void _toggle(Player player) {
    setState(() {
      if (!_squad.remove(player.id)) {
        _squad.add(player.id);
      }
    });
  }

  Future<void> _startMatch() async {
    final opponent = _opponentController.text.trim();
    if (opponent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Gegner eingeben.')),
      );
      return;
    }

    final match = Match(
      id: newId(),
      ownTeamId: scfTeamId,
      opponentName: opponent,
      date: _date,
      isHome: _isHome,
      halfLengthMin: _halfLengthMin,
      status: MatchStatus.geplant,
      phase: MatchPhase.ersteHalbzeit,
      squadPlayerIds: _squad.toList(),
    );
    await ref.read(matchRepositoryProvider).save(match);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.liveMatch,
      arguments: match.id,
    );
  }
}

class _SquadGroup extends StatelessWidget {
  const _SquadGroup({
    required this.label,
    required this.players,
    required this.selected,
    required this.onToggle,
  });

  final String label;
  final List<Player> players;
  final Set<String> selected;
  final ValueChanged<Player> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: ScfText.sectionLabel),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final player in players)
              _SquadChip(
                player: player,
                selected: selected.contains(player.id),
                onTap: () => onToggle(player),
              ),
          ],
        ),
      ],
    );
  }
}

class _SquadChip extends StatelessWidget {
  const _SquadChip({
    required this.player,
    required this.selected,
    required this.onTap,
  });

  final Player player;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = player.position == PlayerPosition.torwart
        ? ScfColors.cyan
        : ScfColors.accent;

    return FilterChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      backgroundColor: ScfColors.surfaceRaised,
      selectedColor: accent.withValues(alpha: 0.18),
      side: BorderSide(
        color: selected ? accent : ScfColors.outline,
        width: selected ? 1.5 : 1,
      ),
      avatar: CircleAvatar(
        backgroundColor: selected ? accent : ScfColors.outline,
        child: Text(
          '${player.number}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.black : ScfColors.textSecondary,
          ),
        ),
      ),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Text(
          player.fullName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

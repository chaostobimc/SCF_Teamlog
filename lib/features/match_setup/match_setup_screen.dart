import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_formatters.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/match.dart';
import '../../data/models/team.dart';
import '../../logic/providers.dart';
import '../../routing/app_router.dart';

/// Neues Spiel anlegen: Team, Gegner, Datum, Heim/Auswärts, Halbzeitlänge.
class MatchSetupScreen extends ConsumerStatefulWidget {
  const MatchSetupScreen({super.key});

  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  final TextEditingController _opponentController = TextEditingController();
  Team? _team;
  DateTime _date = DateTime.now();
  bool _isHome = true;
  int _halfLengthMin = 30;

  @override
  void dispose() {
    _opponentController.dispose();
    super.dispose();
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

  Future<void> _startMatch() async {
    final opponent = _opponentController.text.trim();
    final team = _team;
    if (team == null) {
      _hint('Bitte ein Team auswählen.');
      return;
    }
    if (opponent.isEmpty) {
      _hint('Bitte einen Gegner eingeben.');
      return;
    }
    if (team.fieldPlayers.isEmpty) {
      _hint('Das Team braucht mindestens einen Feldspieler.');
      return;
    }

    final match = Match(
      id: newId(),
      ownTeamId: team.id,
      opponentName: opponent,
      date: _date,
      isHome: _isHome,
      halfLengthMin: _halfLengthMin,
      status: MatchStatus.geplant,
      phase: MatchPhase.ersteHalbzeit,
    );
    await ref.read(matchRepositoryProvider).save(match);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.liveMatch,
      arguments: match.id,
    );
  }

  void _hint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final teams = ref.watch(teamsProvider).valueOrNull ?? const <Team>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Neues Spiel')),
      body: teams.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Zuerst ein Team anlegen.',
                    style: TextStyle(color: ScfColors.textSecondary, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushReplacementNamed(AppRoutes.teams),
                    icon: const Icon(Icons.add),
                    label: const Text('Team anlegen'),
                  ),
                ],
              ),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    DropdownButtonFormField<Team>(
                      initialValue: _team ?? (teams.length == 1 ? teams.first : null),
                      decoration: const InputDecoration(labelText: 'Eigenes Team'),
                      items: [
                        for (final team in teams)
                          DropdownMenuItem(value: team, child: Text(team.name)),
                      ],
                      onChanged: (value) => setState(() => _team = value),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _opponentController,
                      decoration: const InputDecoration(labelText: 'Gegner'),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today_outlined,
                            color: ScfColors.textSecondary),
                        title: const Text('Datum'),
                        subtitle: Text(AppFormatters.date(_date)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _SelectCard(
                            label: 'Heimspiel',
                            icon: Icons.home_outlined,
                            selected: _isHome,
                            onTap: () => setState(() => _isHome = true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SelectCard(
                            label: 'Auswärts',
                            icon: Icons.flight_outlined,
                            selected: !_isHome,
                            onTap: () => setState(() => _isHome = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Halbzeitlänge',
                      style: TextStyle(color: ScfColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final minutes in const [20, 25, 30, 35])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _SelectCard(
                                label: '$minutes min',
                                icon: Icons.timer_outlined,
                                selected: _halfLengthMin == minutes,
                                onTap: () =>
                                    setState(() => _halfLengthMin = minutes),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _startMatch,
                        icon: const Icon(Icons.play_arrow, size: 22),
                        label: const Text(
                          'Spiel starten',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? ScfColors.accent.withValues(alpha: 0.22)
          : ScfColors.surfaceRaised,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? ScfColors.accent : ScfColors.outline,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? ScfColors.accent : ScfColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? ScfColors.textPrimary : ScfColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

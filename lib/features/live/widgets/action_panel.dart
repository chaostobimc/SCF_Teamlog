import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/match_event.dart';
import '../../../data/models/player.dart';
import '../../../logic/match_controller.dart';
import '../../../logic/match_state.dart';

/// Rechte Aktionszone: Kontextbanner, Gegnernummer, Wurf-Ausgang, Schnellaktionen.
class ActionPanel extends StatelessWidget {
  const ActionPanel({
    super.key,
    required this.state,
    required this.controller,
    this.compact = false,
  });

  final MatchState state;
  final MatchController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final player = _selectedPlayer();
    final isKeeper = player?.position == PlayerPosition.torwart;

    return Container(
      margin: EdgeInsets.fromLTRB(compact ? 4 : 8, 8, 8, 8),
      decoration: BoxDecoration(
        color: ScfColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScfColors.outline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Banner(state: state, player: player, controller: controller),
            if (isKeeper)
              _OpponentNumberBar(
                state: state,
                onPick: controller.setOpponentNumber,
                onClear: () => controller.setOpponentNumber(null),
                onKeypad: () => _openKeypad(context),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: state.hasPendingShot
                    ? _PendingShotBox(
                        state: state,
                        controller: controller,
                        isKeeper: isKeeper,
                      )
                    : _QuickBox(
                        state: state,
                        controller: controller,
                        isKeeper: isKeeper,
                        compact: compact,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Player? _selectedPlayer() {
    final id = state.selectedPlayerId;
    if (id == null || state.team == null) return null;
    return state.team!.playerById(id);
  }

  void _openKeypad(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _OpponentKeypad(
        onConfirm: (number) {
          controller.setOpponentNumber(number);
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ Banner

class _Banner extends StatelessWidget {
  const _Banner({
    required this.state,
    required this.player,
    required this.controller,
  });

  final MatchState state;
  final Player? player;
  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    if (state.hasPendingShot) {
      label = 'Wurf aufs Tor – Ergebnis tippen';
      color = ScfColors.success;
    } else if (player == null) {
      label = 'Trikotnummer links wählen – dann Aktion tippen';
      color = ScfColors.textSecondary;
    } else if (player!.position == PlayerPosition.torwart) {
      final number = state.opponentNumber;
      label = number == null
          ? 'Torwart ${player!.shortName} – Gegner-Aktion erfassen'
          : 'Torwart ${player!.shortName} – Gegner #$number';
      color = ScfColors.cyan;
    } else {
      label = 'Aktion für ${player!.shortName} (#${player!.number})';
      color = ScfColors.accent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: const Border(
          bottom: BorderSide(color: ScfColors.outlineSoft),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ScfColors.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (state.hasPendingShot)
            TextButton(
              onPressed: controller.cancelPendingShot,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 28),
              ),
              child: const Text('Storno', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------- Gegner-Nummernleiste

class _OpponentNumberBar extends StatelessWidget {
  const _OpponentNumberBar({
    required this.state,
    required this.onPick,
    required this.onClear,
    required this.onKeypad,
  });

  final MatchState state;
  final ValueChanged<int?> onPick;
  final VoidCallback onClear;
  final VoidCallback onKeypad;

  @override
  Widget build(BuildContext context) {
    final selected = state.opponentNumber;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ScfColors.outlineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('GEGNER-NUMMER', style: ScfText.sectionLabel),
              const SizedBox(width: 8),
              if (selected != null)
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ScfColors.cyanSoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: ScfColors.cyan.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '#$selected ×',
                      style: const TextStyle(
                        color: ScfColors.cyan,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Nummer direkt eingeben',
                onPressed: onKeypad,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.dialpad,
                  color: ScfColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var n = 1; n <= 20; n++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _NumberPickChip(
                      number: n,
                      selected: selected == n,
                      onTap: () => onPick(n),
                    ),
                  ),
                _NumberPickChip(
                  number: 0,
                  label: '—',
                  selected: false,
                  onTap: onClear,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberPickChip extends StatelessWidget {
  const _NumberPickChip({
    required this.number,
    required this.selected,
    required this.onTap,
    this.label,
  });

  final int number;
  final bool selected;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 38,
        decoration: BoxDecoration(
          color: selected ? ScfColors.cyan : ScfColors.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? ScfColors.cyan : ScfColors.outline,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label ?? '$number',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: selected ? Colors.black : ScfColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------ Wurf-Ausgang (pending)

class _PendingShotBox extends StatelessWidget {
  const _PendingShotBox({
    required this.state,
    required this.controller,
    required this.isKeeper,
  });

  final MatchState state;
  final MatchController controller;
  final bool isKeeper;

  @override
  Widget build(BuildContext context) {
    final pending = state.pendingShot!;
    final sevenMeter = pending.isSevenMeter;
    final freeThrow = pending.isFreeThrow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Wurfziel: ${pending.goalZone.label}'
          '${sevenMeter ? ' · 7-Meter' : (freeThrow ? ' · Freiwurf' : '')}',
          style: ScfText.sectionLabel,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ScfTile(
                label: isKeeper ? 'Gegentor' : 'Tor',
                icon: Icons.sports_score,
                color: isKeeper ? ScfColors.danger : ScfColors.success,
                onTap: () => controller.resolvePendingShot(MatchEventType.tor),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ScfTile(
                label: isKeeper ? 'Parade' : 'Gehalten',
                icon: Icons.shield_outlined,
                color: isKeeper ? ScfColors.success : ScfColors.danger,
                onTap: () => controller
                    .resolvePendingShot(MatchEventType.wurfGehalten),
              ),
            ),
            const SizedBox(width: 6),
            if (!isKeeper)
              Expanded(
                child: ScfTile(
                  label: 'Block',
                  icon: Icons.block,
                  color: ScfColors.warning,
                  onTap: () => controller
                      .resolvePendingShot(MatchEventType.wurfGeblockt),
                ),
              )
            else
              const Expanded(child: SizedBox(width: 6)),
          ],
        ),
        const SizedBox(height: 12),
        const Text('WURFART', style: ScfText.sectionLabel),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _contextChip(
                label: 'Feld',
                selected: !sevenMeter && !freeThrow,
                onTap: () =>
                    controller.setThrowContext(sevenMeter: false, freeThrow: false),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _contextChip(
                label: '7-Meter',
                selected: sevenMeter,
                onTap: () => controller.setThrowContext(sevenMeter: true),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _contextChip(
                label: 'Freiwurf',
                selected: freeThrow,
                onTap: () => controller.setThrowContext(freeThrow: true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _contextChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ScfColors.accentSoft : ScfColors.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? ScfColors.accent : ScfColors.outline,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: selected ? ScfColors.accent : ScfColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Schnellaktionen

class _QuickBox extends StatelessWidget {
  const _QuickBox({
    required this.state,
    required this.controller,
    required this.isKeeper,
    required this.compact,
  });

  final MatchState state;
  final MatchController controller;
  final bool isKeeper;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (!isKeeper) ...[
        _tile('Tor', ScfColors.success, Icons.sports_score,
            () => controller.commitQuickAction(MatchEventType.tor)),
        _tile('Fehlwurf', ScfColors.warning, Icons.close,
            () => controller.commitQuickAction(MatchEventType.fehlwurf)),
        _tile('Geblockt', ScfColors.warning, Icons.block,
            () => controller.commitQuickAction(MatchEventType.wurfGeblockt)),
        _tile('Ballverlust', ScfColors.danger, Icons.sync_problem,
            () => controller.commitQuickAction(MatchEventType.ballverlust)),
        _tile('Schrittfehler', ScfColors.warning, Icons.directions_walk,
            () => controller.commitQuickAction(MatchEventType.schrittfehler)),
        _tile('Prellfehler', ScfColors.warning, Icons.loop,
            () => controller.commitQuickAction(MatchEventType.prellfehler)),
        _tile('Gefoult', ScfColors.cyan, Icons.back_hand,
            () => controller.commitQuickAction(MatchEventType.gefoult)),
        _tile('7m geholt', ScfColors.success, Icons.gps_fixed,
            () => controller
                .commitQuickAction(MatchEventType.siebenMeterHerausgeholt)),
        _tile('Duell gew.', ScfColors.violet, Icons.sports_martial_arts,
            () => controller.commitQuickAction(MatchEventType.duelGewonnen)),
        _tile('Stürmerfoul', ScfColors.warning, Icons.report_problem,
            () => controller.commitQuickAction(MatchEventType.stuermerfoul)),
        _tile('Gelb', ScfColors.warning, Icons.style,
            () => controller.commitQuickAction(MatchEventType.gelbeKarte)),
        _tile('2 min', ScfColors.warning, Icons.timer_outlined,
            () => controller.commitQuickAction(MatchEventType.zeitstrafe)),
        _tile('Rot', ScfColors.danger, Icons.flag,
            () => controller.commitQuickAction(MatchEventType.roteKarte)),
        _tile('Blau', ScfColors.cyan, Icons.flag_circle,
            () => controller.commitQuickAction(MatchEventType.blaueKarte)),
      ] else ...[
        _tile('Fehlwurf', ScfColors.cyan, Icons.close,
            () => controller.commitOpponentAction(MatchEventType.fehlwurf)),
        _tile('Block', ScfColors.cyan, Icons.block,
            () => controller.commitOpponentAction(MatchEventType.wurfGeblockt)),
        _tile('7m daneben', ScfColors.cyan, Icons.gps_fixed,
            () => controller.commitOpponentAction(MatchEventType.fehlwurf)),
        _tile('Auszeit', ScfColors.textSecondary, Icons.free_breakfast,
            controller.timeout),
      ],
    ];

    final hint = isKeeper
        ? 'Gegnerwurf: Ziel im Tor tippen, dann „Gegentor“ oder „Parade“.\n'
            'Daneben/Block direkt hier tippen. Gegnernummer bleibt aktiv.'
        : 'Trikotnummer links wählen – dann Aktion tippen.\n'
            'Tastatur: 1–9 Spieler · Leertaste Uhr · Z Rückgängig';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var row = 0; row < tiles.length; row += 3) ...[
          Row(
            children: [
              for (var col = 0; col < 3; col++)
                if (row + col < tiles.length)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        col == 0 ? 0 : 5,
                        0,
                        col == 2 ? 0 : 5,
                        8,
                      ),
                      child: SizedBox(height: 50, child: tiles[row + col]),
                    ),
                  )
                else
                  const Expanded(child: SizedBox(width: 5, height: 50)),
            ],
          ),
        ],
        const SizedBox(height: 2),
        Text(hint, style: ScfText.caption.copyWith(fontSize: 10.5)),
      ],
    );
  }

  Widget _tile(
    String label,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ScfTile(
      label: label,
      icon: icon,
      color: color,
      dense: compact,
      onTap: onTap,
    );
  }

}

// ------------------------------------------------------------- Zahlen-Keypad

class _OpponentKeypad extends StatefulWidget {
  const _OpponentKeypad({required this.onConfirm});

  final ValueChanged<int> onConfirm;

  @override
  State<_OpponentKeypad> createState() => _OpponentKeypadState();
}

class _OpponentKeypadState extends State<_OpponentKeypad> {
  String _buffer = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gegner-Nummer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: ScfColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ScfColors.outline),
            ),
            child: Text(
              _buffer.isEmpty ? '–' : _buffer,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: ScfColors.cyan,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['←', '0', 'OK'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: OutlinedButton(
                          onPressed: () => _press(key),
                          child: Text(
                            key,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _press(String key) {
    setState(() {
      if (key == '←') {
        if (_buffer.isNotEmpty) {
          _buffer = _buffer.substring(0, _buffer.length - 1);
        }
      } else if (key == 'OK') {
        final value = int.tryParse(_buffer);
        if (value != null && value > 0) {
          widget.onConfirm(value);
        }
      } else if (_buffer.length < 2) {
        _buffer += key;
      }
    });
  }
}

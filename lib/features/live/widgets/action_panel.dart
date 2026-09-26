import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/match_event.dart';
import '../../../data/models/player.dart';
import '../../../logic/match_controller.dart';
import '../../../logic/match_state.dart';

/// Rechte Spalte des Live-Screens: Aktionsauswahl je nach Kontext.
class ActionPanel extends StatelessWidget {
  const ActionPanel({
    super.key,
    required this.state,
    required this.controller,
  });

  final MatchState state;
  final MatchController controller;

  Player? get _player {
    final id = state.selectedPlayerId;
    if (id == null || state.team == null) return null;
    return state.team!.playerById(id);
  }

  @override
  Widget build(BuildContext context) {
    final pending = state.pendingShot;
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: pending != null
            ? _ShotResolution(state: state, controller: controller, player: _player)
            : _QuickActions(state: state, controller: controller, player: _player),
      ),
    );
  }
}

// ------------------------------------------------------------ Wurf-Auflösung

class _ShotResolution extends StatelessWidget {
  const _ShotResolution({
    required this.state,
    required this.controller,
    required this.player,
  });

  final MatchState state;
  final MatchController controller;
  final Player? player;

  @override
  Widget build(BuildContext context) {
    final pending = state.pendingShot!;
    final isKeeper = player?.position == PlayerPosition.torwart;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.sports_handball, color: ScfColors.accent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isKeeper
                    ? 'Wurf auf das Tor - Zone: ${pending.goalZone.label}'
                    : 'Wurf - Zone: ${pending.goalZone.label}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ThrowContextChips(
          isSevenMeter: pending.isSevenMeter,
          isFreeThrow: pending.isFreeThrow,
          onContext: (ctx) => controller.setThrowContext(
            sevenMeter: ctx == ThrowContext.sevenMeter,
            freeThrow: ctx == ThrowContext.freeThrow,
          ),
        ),
        const SizedBox(height: 12),
        if (isKeeper) ...[
          _BigButton(
            label: 'Parade',
            color: ScfColors.success,
            icon: Icons.back_hand,
            onPressed: () => controller.resolvePendingShot(MatchEventType.wurfGehalten),
          ),
          const SizedBox(height: 8),
          _BigButton(
            label: 'Gegentor',
            color: ScfColors.danger,
            icon: Icons.sports_score,
            onPressed: () => controller.resolvePendingShot(MatchEventType.tor),
          ),
        ] else ...[
          _BigButton(
            label: 'Tor',
            color: ScfColors.success,
            icon: Icons.check_circle,
            onPressed: () => controller.resolvePendingShot(MatchEventType.tor),
          ),
          const SizedBox(height: 8),
          _BigButton(
            label: 'Gehalten',
            color: ScfColors.info,
            icon: Icons.back_hand,
            onPressed: () => controller.resolvePendingShot(MatchEventType.wurfGehalten),
          ),
          const SizedBox(height: 8),
          _BigButton(
            label: 'Geblockt',
            color: ScfColors.warning,
            icon: Icons.block,
            onPressed: () => controller.resolvePendingShot(MatchEventType.wurfGeblockt),
          ),
          const SizedBox(height: 8),
          const Text(
            'Daneben: Zone am Torrand antippen',
            textAlign: TextAlign.center,
            style: TextStyle(color: ScfColors.textSecondary, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        TextButton(
          onPressed: controller.cancelPendingShot,
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- Schnellaktion

enum ThrowContext { field, sevenMeter, freeThrow }

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.state,
    required this.controller,
    required this.player,
  });

  final MatchState state;
  final MatchController controller;
  final Player? player;

  @override
  Widget build(BuildContext context) {
    final isKeeper = player?.position == PlayerPosition.torwart;
    final throwContext = state.lastCourtZone == CourtZone.siebenMeter
        ? ThrowContext.sevenMeter
        : (state.lastCourtZone == CourtZone.freiwurf
            ? ThrowContext.freeThrow
            : ThrowContext.field);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlayerHeader(player: player),
        const SizedBox(height: 10),
        ThrowContextChips(
          isSevenMeter: throwContext == ThrowContext.sevenMeter,
          isFreeThrow: throwContext == ThrowContext.freeThrow,
          onContext: (ctx) => controller.setQuickContext(switch (ctx) {
            ThrowContext.sevenMeter => CourtZone.siebenMeter,
            ThrowContext.freeThrow => CourtZone.freiwurf,
            ThrowContext.field => null,
          }),
        ),
        const SizedBox(height: 12),
        Text(
          isKeeper ? 'Torhüter-Aktion' : 'Wurf: Zone im Tor antippen',
          style: const TextStyle(
            color: ScfColors.textSecondary,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        if (isKeeper)
          _grid([
            _ActionDef('Parade', ScfColors.success, Icons.back_hand,
                () => controller.commitQuickAction(MatchEventType.parade)),
            _ActionDef('Gegentor', ScfColors.danger, Icons.sports_score,
                () => controller.commitQuickAction(MatchEventType.gegentor)),
          ])
        else
          _grid([
            _ActionDef('Fehlwurf', ScfColors.danger, Icons.close,
                () => controller.commitQuickAction(MatchEventType.fehlwurf)),
            _ActionDef('Geblockt', ScfColors.warning, Icons.block,
                () => controller.commitQuickAction(MatchEventType.wurfGeblockt)),
            _ActionDef('Schrittfehler', null, Icons.directions_walk,
                () => controller.commitQuickAction(MatchEventType.schrittfehler)),
            _ActionDef('Prellfehler', null, Icons.sports_basketball,
                () => controller.commitQuickAction(MatchEventType.prellfehler)),
            _ActionDef('Stürmerfoul', null, Icons.sports_mma,
                () => controller.commitQuickAction(MatchEventType.stuermerfoul)),
            _ActionDef('Ballverlust', ScfColors.danger, Icons.report,
                () => controller.commitQuickAction(MatchEventType.ballverlust)),
            _ActionDef('Gefoult', ScfColors.success, Icons.person_off,
                () => controller.commitQuickAction(MatchEventType.gefoult)),
            _ActionDef('7m geholt', ScfColors.success, Icons.flag,
                () => controller.commitQuickAction(MatchEventType.siebenMeterHerausgeholt)),
            _ActionDef('Duell', ScfColors.success, Icons.sports_kabaddi,
                () => controller.commitQuickAction(MatchEventType.duelGewonnen)),
          ]),
        const SizedBox(height: 14),
        const Text(
          'Sanktionen',
          style: TextStyle(
            color: ScfColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        _grid([
          _ActionDef('Gelb', ScfColors.warning, null,
              () => controller.commitQuickAction(MatchEventType.gelbeKarte)),
          _ActionDef('2 min', ScfColors.accentDim, null,
              () => controller.commitQuickAction(MatchEventType.zeitstrafe)),
          _ActionDef('Rot', ScfColors.danger, null,
              () => controller.commitQuickAction(MatchEventType.roteKarte)),
          _ActionDef('Blau', ScfColors.info, null,
              () => controller.commitQuickAction(MatchEventType.blaueKarte)),
        ]),
      ],
    );
  }

  Widget _grid(List<_ActionDef> defs) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.6,
      children: [
        for (final def in defs)
          _ActionButton(def: def, enabled: player != null),
      ],
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.player});

  final Player? player;

  @override
  Widget build(BuildContext context) {
    if (player == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: ScfColors.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ScfColors.outline),
        ),
        child: const Text(
          'Spieler in der Leiste auswählen',
          style: TextStyle(color: ScfColors.textSecondary),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: ScfColors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ScfColors.accent, width: 1.2),
      ),
      child: Row(
        children: [
          Text(
            '#${player!.number}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: ScfColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              player.fullName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class ThrowContextChips extends StatelessWidget {
  const ThrowContextChips({
    super.key,
    required this.isSevenMeter,
    required this.isFreeThrow,
    required this.onContext,
  });

  final bool isSevenMeter;
  final bool isFreeThrow;
  final ValueChanged<ThrowContext>? onContext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _contextChip('Feldwurf', ThrowContext.field,
              !isSevenMeter && !isFreeThrow),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _contextChip('7 m', ThrowContext.sevenMeter, isSevenMeter),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _contextChip('Freiwurf', ThrowContext.freeThrow, isFreeThrow),
        ),
      ],
    );
  }

  Widget _contextChip(String label, ThrowContext ctx, bool active) {
    return InkWell(
      onTap: onContext == null ? null : () => onContext!(ctx),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? ScfColors.accent : ScfColors.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? ScfColors.accent : ScfColors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? ScfColors.textPrimary : ScfColors.textSecondary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ActionDef {
  const _ActionDef(this.label, this.color, this.icon, this.onPressed);

  final String label;
  final Color? color;
  final IconData? icon;
  final VoidCallback onPressed;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.def, required this.enabled});

  final _ActionDef def;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = def.color;
    return Material(
      color: enabled
          ? (color?.withValues(alpha: 0.22) ?? ScfColors.surfaceCard)
          : ScfColors.surfaceRaised,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? def.onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled ? (color ?? ScfColors.outline) : ScfColors.outline,
              width: color != null ? 1.2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (def.icon != null) ...[
                Icon(def.icon,
                    size: 16,
                    color: enabled
                        ? (color ?? ScfColors.textPrimary)
                        : ScfColors.textSecondary),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  def.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled
                        ? (color != null
                            ? Color.lerp(color, ScfColors.textPrimary, 0.45)
                            : ScfColors.textPrimary)
                        : ScfColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

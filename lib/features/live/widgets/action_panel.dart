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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ScfColors.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isKeeper ? Icons.back_hand : Icons.sports_handball,
                color: ScfColors.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isKeeper ? 'Gegnerwurf' : 'Wurf',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Zone: ${pending.goalZone.label}',
                    style: ScfText.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
            onPressed: () =>
                controller.resolvePendingShot(MatchEventType.wurfGehalten),
          ),
          const SizedBox(height: 8),
          _BigButton(
            label: 'Gegentor',
            color: ScfColors.danger,
            icon: Icons.sports_score,
            onPressed: () =>
                controller.resolvePendingShot(MatchEventType.tor),
          ),
        ] else ...[
          _BigButton(
            label: 'Tor',
            color: ScfColors.success,
            icon: Icons.check_circle,
            onPressed: () =>
                controller.resolvePendingShot(MatchEventType.tor),
          ),
          const SizedBox(height: 8),
          _BigButton(
            label: 'Gehalten',
            color: ScfColors.cyan,
            icon: Icons.back_hand,
            onPressed: () =>
                controller.resolvePendingShot(MatchEventType.wurfGehalten),
          ),
          const SizedBox(height: 8),
          _BigButton(
            label: 'Geblockt',
            color: ScfColors.warning,
            icon: Icons.block,
            onPressed: () =>
                controller.resolvePendingShot(MatchEventType.wurfGeblockt),
          ),
          const SizedBox(height: 8),
          const Text(
            'Daneben: Zone am Torrand antippen',
            textAlign: TextAlign.center,
            style: TextStyle(color: ScfColors.textFaint, fontSize: 11.5),
          ),
        ],
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: controller.cancelPendingShot,
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Abbrechen'),
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
        const SizedBox(height: 14),
        if (isKeeper) ...[
          const _SectionTitle('Torwart'),
          const SizedBox(height: 8),
          _grid([
            _ActionDef('Parade', ScfColors.success, Icons.back_hand,
                () => controller.commitQuickAction(MatchEventType.parade)),
            _ActionDef('Gegentor', ScfColors.danger, Icons.sports_score,
                () => controller.commitQuickAction(MatchEventType.gegentor)),
          ]),
          const SizedBox(height: 14),
          const _SectionTitle('Gegnerwurf'),
          const SizedBox(height: 8),
          _grid([
            _ActionDef('Gegner: daneben', ScfColors.warning, Icons.close,
                () => controller.commitOpponentAction(MatchEventType.fehlwurf)),
            _ActionDef(
                'Gegner: geblockt',
                ScfColors.cyan,
                Icons.block,
                () =>
                    controller.commitOpponentAction(MatchEventType.wurfGeblockt)),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Für das genaue Wurfbild: Torzone antippen, dann Parade/Gegentor.',
            style: TextStyle(color: ScfColors.textFaint, fontSize: 11.5),
          ),
        ] else ...[
          const _SectionTitle('Wurf: Zone im Tor antippen'),
          const SizedBox(height: 8),
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
                () => controller
                    .commitQuickAction(MatchEventType.siebenMeterHerausgeholt)),
            _ActionDef('Duell gewonnen', ScfColors.success, Icons.sports_kabaddi,
                () => controller.commitQuickAction(MatchEventType.duelGewonnen)),
          ]),
        ],
        const SizedBox(height: 14),
        const _SectionTitle('Sanktionen'),
        const SizedBox(height: 8),
        _grid([
          _ActionDef('Gelbe Karte', ScfColors.warning, Icons.style,
              () => controller.commitQuickAction(MatchEventType.gelbeKarte)),
          _ActionDef('2 Minuten', ScfColors.accent, Icons.timer,
              () => controller.commitQuickAction(MatchEventType.zeitstrafe)),
          _ActionDef('Rote Karte', ScfColors.danger, Icons.style,
              () => controller.commitQuickAction(MatchEventType.roteKarte)),
          _ActionDef('Blaue Karte', ScfColors.cyan, Icons.style,
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
      childAspectRatio: 2.5,
      children: [
        for (final def in defs)
          _ActionButton(def: def, enabled: player != null),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: ScfText.sectionLabel);
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.player});

  final Player? player;

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    if (player == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: ScfColors.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ScfColors.outline),
        ),
        child: const Text(
          'Spieler in der Leiste auswählen',
          style: TextStyle(color: ScfColors.textSecondary),
        ),
      );
    }
    final isKeeper = player.position == PlayerPosition.torwart;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: ScfColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isKeeper ? ScfColors.cyan : ScfColors.accent,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (isKeeper ? ScfColors.cyan : ScfColors.accent)
                  .withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '${player.number}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: isKeeper ? ScfColors.cyan : ScfColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  isKeeper ? 'Torwart' : 'Feldspieler',
                  style: ScfText.caption.copyWith(fontSize: 11),
                ),
              ],
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
          child: _contextChip(
              'Feldwurf', ThrowContext.field, !isSevenMeter && !isFreeThrow),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _contextChip('7 m', ThrowContext.sevenMeter, isSevenMeter),
        ),
        const SizedBox(width: 6),
        Expanded(
          child:
              _contextChip('Freiwurf', ThrowContext.freeThrow, isFreeThrow),
        ),
      ],
    );
  }

  Widget _contextChip(String label, ThrowContext ctx, bool active) {
    return InkWell(
      onTap: onContext == null ? null : () => onContext!(ctx),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? ScfColors.accent : ScfColors.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? ScfColors.accent : ScfColors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : ScfColors.textSecondary,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12.5,
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
          ? (color?.withValues(alpha: 0.14) ?? ScfColors.surfaceRaised)
          : ScfColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? def.onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? (color?.withValues(alpha: 0.55) ?? ScfColors.outline)
                  : ScfColors.outlineSoft,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              if (def.icon != null) ...[
                Icon(def.icon,
                    size: 17,
                    color: enabled
                        ? (color ?? ScfColors.textPrimary)
                        : ScfColors.textFaint),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  def.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled
                        ? ScfColors.textPrimary
                        : ScfColors.textFaint,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
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
      height: 54,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.black, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
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

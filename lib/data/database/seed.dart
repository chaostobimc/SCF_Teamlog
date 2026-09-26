import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/player.dart';
import '../models/team.dart';

/// Die App ist fest auf einen Verein ausgelegt: SC Freising.
const String scfTeamId = 'scf-freising';
const String scfTeamName = 'SC Freising';

/// Holt das SC-Freising-Team (nach dem Seed immer vorhanden).
Team? scfTeam(Box<Team> box) => box.get(scfTeamId);

/// Frisches Modell ohne Persistenz (Fallback, falls die Box leer ist).
Team seedScfTeamModel() {
  return Team(
    id: scfTeamId,
    name: scfTeamName,
    primaryColor: const Color(0xFF2563EB),
    secondaryColor: const Color(0xFFF1F5F9),
    players: const [],
  );
}

/// Legt den SC-Freising-Kader beim ersten Start an (leerer Kader).
Future<void> seedScfTeam(Box<Team> box) async {
  if (box.containsKey(scfTeamId)) return;
  await box.put(scfTeamId, seedScfTeamModel());
}

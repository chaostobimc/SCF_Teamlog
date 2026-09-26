import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../logic/providers.dart';
import '../../routing/app_router.dart';
import 'team_edit_screen.dart';

class TeamListScreen extends ConsumerWidget {
  const TeamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(teamsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Teams')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.teamEdit),
        icon: const Icon(Icons.add),
        label: const Text('Neues Team'),
      ),
      body: teams.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_outlined,
                      size: 64,
                      color: ScfColors.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text(
                    'Noch keine Teams angelegt',
                    style: TextStyle(color: ScfColors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            team.primaryColor,
                            team.primaryColor.withValues(alpha: 0.75),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    title: Text(
                      team.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${team.players.length} Spieler'
                      '${team.goalkeepers.isNotEmpty ? ' · ${team.goalkeepers.length} TW' : ''}',
                      style: const TextStyle(color: ScfColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.teamEdit,
                      arguments: TeamEditArgs(team: team),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

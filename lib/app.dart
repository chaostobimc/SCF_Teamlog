import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

class ScfTeamlogApp extends StatelessWidget {
  const ScfTeamlogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCF Teamlog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

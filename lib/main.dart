import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/gazette_repository.dart';
import 'theme/app_theme.dart';
import 'utils/app_info.dart';

void main() {
  runApp(const ResultDeskApp());
}

class ResultDeskApp extends StatelessWidget {
  const ResultDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GazetteRepository()..init(),
      child: MaterialApp(
        title: AppInfo.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const HomeScreen(),
      ),
    );
  }
}

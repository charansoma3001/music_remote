import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/music_provider.dart';
import 'screens/discovery_screen.dart';
import 'screens/control_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MusicProvider()..initialize(),
      child: MaterialApp(
        title: 'Apple Music Remote',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          cardTheme: const CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          cardTheme: const CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: Consumer<MusicProvider>(
          builder: (context, provider, _) {
            // Show control screen if already connected, otherwise discovery
            return provider.isConnected
                ? const ControlScreen()
                : const DiscoveryScreen();
          },
        ),
      ),
    );
  }
}

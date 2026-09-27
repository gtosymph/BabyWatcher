import 'package:flutter/material.dart';

import 'camera/camera_screen.dart';
import 'monitor/pairing_screen.dart';
import 'update/update_dialogs.dart';
import 'update/update_service.dart';

void main() => runApp(const BabycamApp());

class BabycamApp extends StatelessWidget {
  const BabycamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BabyWatcher',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF6B7FD7), useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6B7FD7),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    if (UpdateService.isSupported) {
      UpdateService().currentVersion().then((v) {
        if (mounted) setState(() => _version = v.toString());
      });
    }
    // Vérification discrète au démarrage, après le premier affichage.
    WidgetsBinding.instance.addPostFrameCallback((_) => checkForUpdate(context));
  }

  @override
  Widget build(BuildContext context) {
    void go(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(
        title: const Text('BabyWatcher'),
        actions: [
          if (UpdateService.isSupported)
            IconButton(
              tooltip: 'Vérifier les mises à jour',
              icon: const Icon(Icons.system_update),
              onPressed: () => checkForUpdate(context, silent: false),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Choisis le rôle de ce téléphone',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              _RoleButton(
                icon: Icons.videocam,
                label: 'Caméra',
                hint: 'Dans la chambre, branché sur secteur',
                onTap: () => go(const CameraScreen()),
              ),
              const SizedBox(height: 16),
              _RoleButton(
                icon: Icons.monitor_heart_outlined,
                label: 'Moniteur',
                hint: 'Avec les parents',
                onTap: () => go(const PairingScreen()),
              ),
              const Spacer(),
              const Text('Les deux téléphones doivent être sur le même WiFi.',
                  textAlign: TextAlign.center),
              if (_version != null)
                Text('Version $_version',
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  const _RoleButton(
      {required this.icon, required this.label, required this.hint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(icon, size: 48),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.headlineSmall),
                    Text(hint),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

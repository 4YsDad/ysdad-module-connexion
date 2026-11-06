// Exemple complet : lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart'; // créé par « flutterfire configure »
import 'ysdad_connexion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MonAppli());
}

class MonAppli extends StatelessWidget {
  const MonAppli({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trouve-tout',
      debugShowCheckedModeBanner: false,
      home: YsdadAuthGate(
        config: const YsdadConnexionConfig(
          appName: 'Trouve-tout',
          logoAsset: 'assets/images/logo.png',            // facultatif
          backgroundAsset: 'assets/images/background.jpg', // facultatif
          accentColor: Color(0xFF673AB7),
        ),
        onSignedIn: (user) => debugPrint('Connecté : ${user.email}'),
        builder: (context, user) => Accueil(nom: user.displayName ?? user.email ?? ''),
      ),
    );
  }
}

class Accueil extends StatelessWidget {
  const Accueil({super.key, required this.nom});
  final String nom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trouve-tout'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: ysdadDeconnexion,
          ),
        ],
      ),
      body: Center(child: Text('Bonjour $nom!')),
    );
  }
}

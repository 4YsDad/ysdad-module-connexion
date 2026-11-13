# Module « Connexion » — Ysdad 💙

Page de connexion prête à l'emploi, la même pour toutes vos applis :
**Continuer avec Google** et **Continuer avec Apple** en premier, puis (en option) courriel + mot de passe avec onglets Connexion / Inscription, « Mot de passe oublié? » et vérification du courriel.
Style inspiré de Ciné-surveillance (fond, logo, nom en majuscules, champs arrondis). Fonctionne sur Android, iPhone et en version web.
Apple s'affiche seulement sur iPhone, Mac et web (sur Android : option `appleOnAndroid: true`).

## 0. (Recommandé) Dépendance Git plutôt que copie

Dans `pubspec.yaml` de l'appli :
```yaml
dependencies:
  ysdad_connexion:
    git:
      url: https://github.com/4YsDad/ysdad-module-connexion.git
      ref: main
```
Puis `flutter pub get` et `import 'package:ysdad_connexion/ysdad_connexion.dart';`.
Les étapes 1 et 2 ci-dessous ne sont alors plus nécessaires (Firebase reste à brancher : étapes 3 à 6).

## 1. Copier 1 fichier dans votre projet
- `lib/ysdad_connexion.dart` → dans le dossier `lib/` du projet

## 2. Ajouter les dépendances
```
flutter pub add firebase_core firebase_auth google_sign_in sign_in_with_apple crypto shared_preferences
```
(Versions testées : firebase_core 5.1, firebase_auth 7.0, google_sign_in 7.2, sign_in_with_apple 8.2, crypto 3.0, shared_preferences 2.5 — Flutter 3.47.)

## 3. Brancher Firebase (une seule fois par appli)
```
dart pub global activate flutterfire_cli
flutterfire configure
```
Choisissez le projet Firebase et les plateformes (android, ios, web). Ça crée `lib/firebase_options.dart`.

## 4. Activer les fournisseurs dans la console Firebase
Console Firebase → **Authentication** → **Méthode de connexion** :
1. **Adresse e-mail/Mot de passe** → Activer.
2. **Google** → Activer → choisir un courriel d'assistance → Enregistrer.
3. **Apple** → Activer (voir l'étape 6 pour les champs).
4. Onglet **Paramètres → Domaines autorisés** : ajoutez le domaine de la version web (ex. `mon-appli.web.app` y est déjà si vous utilisez Firebase Hosting).
5. (Facultatif) **Modèles** : passez les courriels (vérification, mot de passe) en français.

## 5. Android : empreinte SHA-1 (obligatoire pour Google)
Dans le dossier `android/` du projet :
```
./gradlew signingReport
```
(Sous Windows : `gradlew signingReport`.) Copiez les lignes **SHA1** et **SHA-256** de `debug` **et** de `release`.
Console Firebase → ⚙️ Paramètres du projet → votre appli Android → **Ajouter une empreinte**.
**Important pour Google Play** : ajoutez aussi l'empreinte SHA-1 de la « clé de signature de l'appli » (Play Console → Configuration → Intégrité de l'appli). Sinon, Google fonctionnera en test mais pas une fois publié.
Ensuite, retéléchargez `google-services.json` (ou relancez `flutterfire configure`).

Si Google affiche « serverClientId must be provided » : ouvrez `google-services.json`, copiez le `client_id` dont `client_type` vaut `3` et passez-le dans `googleServerClientId: '...'`.

## 6. Apple (Sign in with Apple)
Il faut le compte développeur Apple (99 $ US/an) et un Mac pour la partie iPhone.
1. **developer.apple.com → Certificates, IDs & Profiles → Identifiers** → votre App ID → cochez **Sign In with Apple** → Save.
2. Dans Xcode (`ios/Runner.xcworkspace`) → Runner → **Signing & Capabilities** → **+ Capability** → **Sign in with Apple**.
3. Console Firebase → fournisseur **Apple** : pour iPhone seulement, rien d'autre à remplir.
4. **Pour le web (et Android)** : créez aussi un **Services ID** (Identifiers → +), cochez Sign In with Apple → Configure → domaine `VOTRE-PROJET.firebaseapp.com` et URL de retour `https://VOTRE-PROJET.firebaseapp.com/__/auth/handler`. Créez une **Key** avec Sign In with Apple, téléchargez le fichier .p8. Entrez dans Firebase : Services ID, Team ID, Key ID et la clé privée.
5. Google côté iPhone : dans `ios/Runner/Info.plist`, ajoutez l'URL scheme `REVERSED_CLIENT_ID` de `GoogleService-Info.plist` (voir la doc de google_sign_in).

Note : Apple exige « Continuer avec Apple » dans toute appli iPhone qui offre Google. Le module le fait déjà.

## 7. Utiliser le module (3 lignes)
Dans `main.dart`, remplacez `home:` par :
```dart
home: YsdadAuthGate(
  config: const YsdadConnexionConfig(appName: 'Trouve-tout'),
  builder: (context, user) => const MonAccueil(),
),
```
Si personne n'est connecté → page de connexion. Sinon → votre appli. Pour se déconnecter : `ysdadDeconnexion();`
Voir `exemple_integration.dart` pour un exemple complet.

## Options (facultatif)
- Logo : `logoAsset: 'assets/images/logo.png'` · Fond : `backgroundAsset: 'assets/images/background.jpg'` (déclarez-les sous `flutter: assets:` dans `pubspec.yaml`)
- Couleurs : `accentColor: Color(0xFF673AB7)`, `backgroundColor: Color(0xFF1A0B2E)`
- Après connexion : `onSignedIn: (user) { ... }` (sur `YsdadAuthGate` ou `YsdadLoginPage`)
- Masquer une méthode : `showGoogle: false`, `showApple: false`, `allowEmail: false`
- Apple sur Android : `appleOnAndroid: true` (demande le Services ID de l'étape 6)
- Ne pas bloquer en attendant la vérification du courriel : `requireEmailVerification: false`
- Le dernier courriel saisi est retenu automatiquement.
- Messages d'erreur en français réutilisables : `ysdadMessageErreur(e)`.

### Emplacements libres (v1.1)

| Option | Rôle |
|---|---|
| `entete` | Widget affiché au-dessus du nom (mascotte, illustration). Remplace `logoAsset`. |
| `piedDePage` | Widget sous le formulaire, dans la zone défilante (ex. bouton « Compte démo »). |
| `afficherNomAppli` | `false` pour cacher le nom en majuscules. |
| `courrielOuvertParDefaut` | `true` pour afficher tout de suite le formulaire courriel. |

```dart
YsdadConnexionConfig(
  appName: 'Maître de chantier',
  entete: Image.asset('assets/images/mascotte.png', height: 220),
  piedDePage: FilledButton(onPressed: entrerDemo, child: const Text('Compte démo')),
)
```

// Module « Connexion » — Ysdad 💙
// Page de connexion réutilisable : Google, Apple, puis courriel + mot de passe.
// Voir LISEZMOI.md pour l'installation.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Réglages visuels et techniques de la page de connexion.
class YsdadConnexionConfig {
  const YsdadConnexionConfig({
    required this.appName,
    this.logoAsset,
    this.backgroundAsset,
    this.accentColor = const Color(0xFF673AB7),
    this.backgroundColor = const Color(0xFF1A0B2E),
    this.showGoogle = true,
    this.showApple = true,
    this.appleOnAndroid = false,
    this.allowEmail = true,
    this.requireEmailVerification = true,
    this.googleServerClientId,
    this.googleClientId,
  });

  /// Nom affiché sous le logo (ex. « Trouve-tout »).
  final String appName;

  /// Chemin d'un logo dans assets/ (facultatif).
  final String? logoAsset;

  /// Chemin d'une image de fond dans assets/ (facultatif).
  final String? backgroundAsset;

  /// Couleur des boutons et du champ actif.
  final Color accentColor;

  /// Couleur de fond si aucune image n'est fournie.
  final Color backgroundColor;

  final bool showGoogle;
  final bool showApple;

  /// Afficher Apple sur Android aussi (demande une config Apple « Services ID »).
  final bool appleOnAndroid;

  /// Offrir la connexion par courriel + mot de passe.
  final bool allowEmail;

  /// Bloquer l'accès tant que le courriel n'est pas vérifié (comptes courriel seulement).
  final bool requireEmailVerification;

  /// Android : « Web client ID » (client_type 3) de google-services.json, si nécessaire.
  final String? googleServerClientId;

  /// iOS/macOS : CLIENT_ID de GoogleService-Info.plist, si nécessaire.
  final String? googleClientId;
}

// ─────────────────────────────────────────────────────────────
// Enveloppe : page de connexion si personne n'est connecté, sinon l'appli.
// ─────────────────────────────────────────────────────────────

class YsdadAuthGate extends StatelessWidget {
  const YsdadAuthGate({
    super.key,
    required this.config,
    required this.builder,
    this.onSignedIn,
  });

  final YsdadConnexionConfig config;

  /// Construit l'appli une fois l'utilisateur connecté.
  final Widget Function(BuildContext context, User user) builder;

  /// Appelé une fois après chaque connexion réussie.
  final void Function(User user)? onSignedIn;

  bool _needsVerification(User u) {
    if (!config.requireEmailVerification || u.emailVerified) return false;
    return u.providerData.any((p) => p.providerId == 'password') &&
        !u.providerData.any((p) => p.providerId != 'password');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: config.backgroundColor,
            body: Center(child: CircularProgressIndicator(color: config.accentColor)),
          );
        }
        final user = snap.data;
        if (user == null) {
          return YsdadLoginPage(config: config, onSignedIn: onSignedIn);
        }
        if (_needsVerification(user)) {
          return YsdadVerificationCourrielPage(config: config, user: user);
        }
        return builder(context, user);
      },
    );
  }
}

/// Déconnexion complète (Firebase + Google).
Future<void> ysdadDeconnexion() async {
  try {
    if (!kIsWeb) await GoogleSignIn.instance.signOut();
  } catch (_) {}
  await FirebaseAuth.instance.signOut();
}

// ─────────────────────────────────────────────────────────────
// Messages d'erreur en français
// ─────────────────────────────────────────────────────────────

String ysdadMessageErreur(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'L\'adresse courriel n\'est pas valide.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Courriel ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec ce courriel. Essayez l\'onglet Connexion.';
      case 'weak-password':
        return 'Mot de passe trop faible : au moins 6 caractères.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      case 'network-request-failed':
        return 'Pas de connexion Internet. Vérifiez votre réseau.';
      case 'account-exists-with-different-credential':
        return 'Ce courriel est déjà lié à une autre méthode de connexion (Google, Apple ou mot de passe). Utilisez celle-là.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'web-context-canceled':
        return 'Connexion annulée.';
      case 'popup-blocked':
        return 'La fenêtre de connexion a été bloquée par le navigateur. Autorisez les fenêtres surgissantes.';
      case 'operation-not-allowed':
        return 'Cette méthode de connexion n\'est pas activée pour cette appli.';
      case 'requires-recent-login':
        return 'Par sécurité, reconnectez-vous puis réessayez.';
      case 'missing-email':
        return 'Entrez votre courriel.';
      default:
        return 'Erreur de connexion (${e.code}). Réessayez.';
    }
  }
  if (e is GoogleSignInException) {
    if (e.code == GoogleSignInExceptionCode.canceled) return 'Connexion annulée.';
    return 'Connexion Google impossible. Réessayez.';
  }
  if (e is SignInWithAppleAuthorizationException) {
    if (e.code == AuthorizationErrorCode.canceled) return 'Connexion annulée.';
    return 'Connexion Apple impossible. Réessayez.';
  }
  return 'Une erreur est survenue. Réessayez.';
}

// ─────────────────────────────────────────────────────────────
// Page de connexion
// ─────────────────────────────────────────────────────────────

class YsdadLoginPage extends StatefulWidget {
  const YsdadLoginPage({super.key, required this.config, this.onSignedIn});

  final YsdadConnexionConfig config;
  final void Function(User user)? onSignedIn;

  @override
  State<YsdadLoginPage> createState() => _YsdadLoginPageState();
}

class _YsdadLoginPageState extends State<YsdadLoginPage> {
  static const _cleCourriel = 'ysdad_dernier_courriel';
  static bool _googleInit = false;

  final _formKey = GlobalKey<FormState>();
  final _courriel = TextEditingController();
  final _motDePasse = TextEditingController();
  final _confirmation = TextEditingController();

  bool _inscription = false;
  bool _cache = true;
  bool _occupe = false;
  bool _voirCourriel = false;
  String? _erreur;

  YsdadConnexionConfig get c => widget.config;

  bool get _appleSupporte {
    if (!c.showApple) return false;
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.android:
        return c.appleOnAndroid;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final e = p.getString(_cleCourriel);
      if (e != null && mounted) setState(() => _courriel.text = e);
    });
  }

  @override
  void dispose() {
    _courriel.dispose();
    _motDePasse.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _executer(Future<UserCredential?> Function() action) async {
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      final cred = await action();
      final u = cred?.user;
      if (u != null) widget.onSignedIn?.call(u);
    } catch (e) {
      final msg = ysdadMessageErreur(e);
      if (mounted && msg != 'Connexion annulée.') setState(() => _erreur = msg);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  // --- Google ---
  Future<UserCredential?> _google() async {
    final auth = FirebaseAuth.instance;
    if (kIsWeb) return auth.signInWithPopup(GoogleAuthProvider());
    final gs = GoogleSignIn.instance;
    if (!_googleInit) {
      await gs.initialize(clientId: c.googleClientId, serverClientId: c.googleServerClientId);
      _googleInit = true;
    }
    final compte = await gs.authenticate();
    final idToken = compte.authentication.idToken;
    return auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  }

  // --- Apple ---
  Future<UserCredential?> _apple() async {
    final auth = FirebaseAuth.instance;
    final provider = AppleAuthProvider()..addScope('email')..addScope('name');
    if (kIsWeb) return auth.signInWithPopup(provider);
    if (defaultTargetPlatform == TargetPlatform.android) {
      return auth.signInWithProvider(provider); // passe par le navigateur
    }
    // iOS / macOS : feuille native d'Apple
    final brut = _nonce();
    final hache = sha256.convert(utf8.encode(brut)).toString();
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      nonce: hache,
    );
    final cred = OAuthProvider('apple.com').credential(
      idToken: apple.identityToken,
      rawNonce: brut,
      accessToken: apple.authorizationCode,
    );
    final res = await auth.signInWithCredential(cred);
    final nom = [apple.givenName, apple.familyName].whereType<String>().join(' ').trim();
    if (nom.isNotEmpty && (res.user?.displayName ?? '').isEmpty) {
      await res.user?.updateDisplayName(nom);
    }
    return res;
  }

  String _nonce([int n = 32]) {
    const cs = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(n, (_) => cs[r.nextInt(cs.length)]).join();
  }

  // --- Courriel ---
  Future<UserCredential?> _soumettreCourriel() async {
    if (!_formKey.currentState!.validate()) return null;
    final courriel = _courriel.text.trim();
    (await SharedPreferences.getInstance()).setString(_cleCourriel, courriel);
    final auth = FirebaseAuth.instance;
    if (_inscription) {
      final cred = await auth.createUserWithEmailAndPassword(email: courriel, password: _motDePasse.text);
      await cred.user?.sendEmailVerification();
      return cred;
    }
    return auth.signInWithEmailAndPassword(email: courriel, password: _motDePasse.text);
  }

  Future<void> _motDePasseOublie() async {
    final ctrl = TextEditingController(text: _courriel.text.trim());
    final courriel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mot de passe oublié?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Entrez votre courriel. Vous recevrez un lien pour choisir un nouveau mot de passe.'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Courriel', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.accentColor),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Envoyer le lien'),
          ),
        ],
      ),
    );
    if (courriel == null || courriel.isEmpty || !mounted) return;
    final messager = ScaffoldMessenger.of(context);
    try {
      await FirebaseAuth.instance.setLanguageCode('fr');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: courriel);
      messager.showSnackBar(SnackBar(
        content: Text('Si un compte existe pour $courriel, un courriel de réinitialisation vient d\'être envoyé. Vérifiez aussi vos indésirables.'),
      ));
    } catch (e) {
      messager.showSnackBar(SnackBar(content: Text(ysdadMessageErreur(e))));
    }
  }

  // --- Interface ---
  InputDecoration _deco(String label, {Widget? suffix}) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        floatingLabelStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.35),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.accentColor, width: 2),
        ),
      );

  Widget _boutonFournisseur({
    required String texte,
    required Widget icone,
    required Color fond,
    required Color encre,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: fond,
          foregroundColor: encre,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          icone,
          const SizedBox(width: 10),
          Text(texte, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _onglet(String texte, bool actif, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: actif ? Colors.white.withValues(alpha: 0.85) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(texte,
              style: TextStyle(
                color: actif ? Colors.black : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              )),
        ),
      );

  Widget _formulaireCourriel() {
    return Form(
      key: _formKey,
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _onglet('Connexion', !_inscription, () => setState(() => _inscription = false)),
          const SizedBox(width: 12),
          _onglet('Inscription', _inscription, () => setState(() => _inscription = true)),
        ]),
        const SizedBox(height: 14),
        TextFormField(
          controller: _courriel,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: _deco('Courriel'),
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) return 'Entrez votre courriel.';
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Courriel invalide.';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _motDePasse,
          style: const TextStyle(color: Colors.white),
          obscureText: _cache,
          autofillHints: [_inscription ? AutofillHints.newPassword : AutofillHints.password],
          decoration: _deco('Mot de passe',
              suffix: IconButton(
                tooltip: _cache ? 'Afficher' : 'Masquer',
                icon: Icon(_cache ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                onPressed: () => setState(() => _cache = !_cache),
              )),
          validator: (v) {
            if ((v ?? '').isEmpty) return 'Entrez votre mot de passe.';
            if (_inscription && v!.length < 6) return 'Au moins 6 caractères.';
            return null;
          },
          onFieldSubmitted: (_) => _inscription ? null : _executer(_soumettreCourriel),
        ),
        if (_inscription) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmation,
            style: const TextStyle(color: Colors.white),
            obscureText: _cache,
            decoration: _deco('Confirmer le mot de passe'),
            validator: (v) => v != _motDePasse.text ? 'Les mots de passe ne correspondent pas.' : null,
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _occupe ? null : () => _executer(_soumettreCourriel),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(_inscription ? 'CRÉER MON COMPTE' : 'CONNEXION',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        ),
        if (!_inscription)
          TextButton(
            onPressed: _occupe ? null : _motDePasseOublie,
            child: const Text('Mot de passe oublié?', style: TextStyle(color: Colors.white)),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final montrerCourriel = c.allowEmail && (_voirCourriel || (!c.showGoogle && !_appleSupporte));
    return Scaffold(
      backgroundColor: c.backgroundColor,
      body: Stack(fit: StackFit.expand, children: [
        if (c.backgroundAsset != null) Image.asset(c.backgroundAsset!, fit: BoxFit.cover),
        Container(color: Colors.black.withAlpha(c.backgroundAsset != null ? 100 : 0)),
        SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final largeur = (box.maxWidth - 24).clamp(280.0, 360.0);
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Center(
                  child: SizedBox(
                    width: largeur,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: AutofillGroup(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          if (c.logoAsset != null) Image.asset(c.logoAsset!, height: 150),
                          const SizedBox(height: 8),
                          Text(c.appName.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                          const SizedBox(height: 20),
                          if (c.showGoogle) ...[
                            _boutonFournisseur(
                              texte: 'Continuer avec Google',
                              icone: const _LogoGoogle(),
                              fond: Colors.white,
                              encre: Colors.black87,
                              onTap: _occupe ? null : () => _executer(_google),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_appleSupporte) ...[
                            _boutonFournisseur(
                              texte: 'Continuer avec Apple',
                              icone: const Icon(Icons.apple, size: 24),
                              fond: Colors.black,
                              encre: Colors.white,
                              onTap: _occupe ? null : () => _executer(_apple),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (c.allowEmail && (c.showGoogle || _appleSupporte)) ...[
                            Row(children: [
                              const Expanded(child: Divider(color: Colors.white38)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('ou', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                              ),
                              const Expanded(child: Divider(color: Colors.white38)),
                            ]),
                            if (!montrerCourriel)
                              TextButton.icon(
                                onPressed: () => setState(() => _voirCourriel = true),
                                icon: const Icon(Icons.mail_outline, color: Colors.white),
                                label: const Text('Utiliser un courriel et un mot de passe',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            const SizedBox(height: 8),
                          ],
                          if (montrerCourriel) _formulaireCourriel(),
                          if (_occupe) ...[
                            const SizedBox(height: 16),
                            CircularProgressIndicator(color: c.accentColor),
                          ],
                          if (_erreur != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade700.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(_erreur!, style: const TextStyle(color: Colors.white)),
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Page « Vérifiez votre courriel »
// ─────────────────────────────────────────────────────────────

class YsdadVerificationCourrielPage extends StatefulWidget {
  const YsdadVerificationCourrielPage({super.key, required this.config, required this.user});
  final YsdadConnexionConfig config;
  final User user;

  @override
  State<YsdadVerificationCourrielPage> createState() => _YsdadVerificationCourrielPageState();
}

class _YsdadVerificationCourrielPageState extends State<YsdadVerificationCourrielPage> {
  String? _message;
  bool _occupe = false;

  Future<void> _verifier() async {
    setState(() => _occupe = true);
    await widget.user.reload(); // userChanges() relance l'enveloppe si c'est vérifié
    final u = FirebaseAuth.instance.currentUser;
    if (mounted && !(u?.emailVerified ?? false)) {
      setState(() => _message = 'Pas encore vérifié. Cliquez sur le lien reçu par courriel, puis réessayez.');
    }
    if (mounted) setState(() => _occupe = false);
  }

  Future<void> _renvoyer() async {
    try {
      await FirebaseAuth.instance.setLanguageCode('fr');
      await widget.user.sendEmailVerification();
      setState(() => _message = 'Nouveau courriel envoyé à ${widget.user.email}.');
    } catch (e) {
      setState(() => _message = ysdadMessageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return Scaffold(
      backgroundColor: c.backgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.mark_email_unread_outlined, size: 72, color: c.accentColor),
              const SizedBox(height: 16),
              const Text('Vérifiez votre courriel',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'Un lien de confirmation a été envoyé à ${widget.user.email}. '
                'Cliquez dessus (regardez aussi dans les indésirables), puis revenez ici.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _occupe ? null : _verifier,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('J\'ai confirmé mon courriel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              TextButton(onPressed: _renvoyer, child: const Text('Renvoyer le courriel', style: TextStyle(color: Colors.white))),
              TextButton(
                  onPressed: ysdadDeconnexion,
                  child: const Text('Utiliser un autre compte', style: TextStyle(color: Colors.white70))),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Petit « G » multicolore dessiné (aucun fichier image requis).
class _LogoGoogle extends StatelessWidget {
  const _LogoGoogle();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 22,
        height: 22,
        child: CustomPaint(painter: _GPainter()),
      );
}

class _GPainter extends CustomPainter {
  const _GPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width * 0.2;
    final r = Rect.fromLTWH(w / 2, w / 2, s.width - w, s.height - w);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    canvas.drawArc(r, -0.25 * pi, -0.55 * pi, false, p(const Color(0xFFEA4335)));
    canvas.drawArc(r, -0.8 * pi, -0.45 * pi, false, p(const Color(0xFFFBBC05)));
    canvas.drawArc(r, 0.75 * pi, -0.7 * pi, false, p(const Color(0xFF34A853)));
    canvas.drawArc(r, 0.05 * pi, -0.05 * pi - 0.0, false, p(const Color(0xFF4285F4)));
    canvas.drawArc(r, 0.0, 0.25 * pi, false, p(const Color(0xFF4285F4)));
    canvas.drawLine(Offset(s.width / 2, s.height / 2), Offset(s.width - w / 2, s.height / 2),
        p(const Color(0xFF4285F4)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

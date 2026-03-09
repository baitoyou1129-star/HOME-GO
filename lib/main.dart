import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:frotter/auth/signup_choice_page.dart';
import 'package:frotter/chat/chat_pages.dart';
import 'package:frotter/client/client_signup_page.dart';
import 'package:frotter/profile/avatar.dart';
import 'package:frotter/profile/avatar_picker_page.dart';
import 'package:frotter/profile/profile_edit_page.dart';
import 'package:frotter/ratings/ratings_page.dart';
import 'package:frotter/search/worker_search.dart';
import 'package:frotter/stamp_rally/coupon_roulette.dart';
import 'package:frotter/worker/worker_pages.dart';
import 'package:frotter/worker/worker_signup_start_page.dart';
import 'package:frotter/worker/worker_signup_page.dart';
import 'package:frotter/notifications/notifications_page.dart';

// カラーテーマ
// - メイン: ライトブルー
// - サブ: ミントグリーン
// - アクセント: オレンジ
const Color kMainLightBlue = Color(0xFF4DA3FF);
const Color kSubMintGreen = Color(0xFF2ED6B3);
const Color kAccentOrange = Color(0xFFFF8A00);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late final Future<void> _initFuture = _init();

  Future<void> _init() async {
    // どこで止まっているか分かるようにタイムアウト＋例外化
    // ※ もしWindowsアプリとして実行している場合、FlutterFire未設定だと失敗します。
    await Firebase.initializeApp().timeout(const Duration(seconds: 20));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('起動中…'),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            final err = snapshot.error;
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '初期化に失敗しました',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$err',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Android実機/エミュで動かしているか、Firebase設定（google-services.json）が正しいか確認してください。',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return const HomeGoApp();
        },
      ),
    );
  }
}

class HomeGoApp extends StatelessWidget {
  const HomeGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ColorScheme.fromSeed(
      seedColor: kMainLightBlue,
      brightness: Brightness.light,
    );
    final colorScheme = base.copyWith(
      primary: kMainLightBlue,
      secondary: kSubMintGreen,
      tertiary: kAccentOrange,
    );

    return MaterialApp(
      title: 'ルームサポ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5FBFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: kMainLightBlue,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: colorScheme.outlineVariant,
          thickness: 1,
        ),
      ),
      home: const AuthFlow(),
    );
  }
}

/// Firebase Authentication だけでログインを完結させる。
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return HomeScreen(
        email: user.email ?? "unknown",
        onLogout: () async {
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn.instance.signOut();
          if (!mounted) return;
          setState(() {});
        },
      );
    }

    return LoginScreen(
      onLoggedIn: (_) => setState(() {}),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLoggedIn,
  });

  final ValueChanged<String> onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _progress;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'メール形式が不正です。';
      case 'user-not-found':
        return 'ユーザーが見つかりません（新規登録してください）。';
      case 'wrong-password':
        return 'パスワードが違います。';
      case 'weak-password':
        return 'パスワードが弱すぎます（6文字以上）。';
      case 'email-already-in-use':
        return 'このメールは既に登録されています。';
      default:
        return 'ログインに失敗しました。';
    }
  }

  Future<void> _emailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _progress = "ログイン中…";
    });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      widget.onLoggedIn(cred.user?.email ?? email);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyAuthError(e.code))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _signup() async {
    if (_loading) return;
    final initialEmail = _emailController.text.trim();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignupChoicePage(
          onChooseClient: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ClientSignupPage(
                  initialEmail: initialEmail.isEmpty ? null : initialEmail,
                  onSignedUp: widget.onLoggedIn,
                ),
              ),
            );
          },
          onChooseWorker: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorkerSignupStartPage(
                  initialEmail: initialEmail.isEmpty ? null : initialEmail,
                  onSignedUp: widget.onLoggedIn,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _googleLogin() async {
    setState(() {
      _loading = true;
      _progress = "Googleログイン中…";
    });
    try {
      // google_sign_in v7 では initialize が必須（起動時に固まるのを避けるためここで実行）
      await GoogleSignIn.instance.initialize().timeout(const Duration(seconds: 20));
      final googleUser = await GoogleSignIn.instance
          .authenticate()
          .timeout(const Duration(seconds: 25));

      final googleIdToken = googleUser.authentication.idToken;
      if (googleIdToken == null || googleIdToken.isEmpty) {
        throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
          description: 'Missing Google ID token.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: googleIdToken);
      final userCred = await FirebaseAuth.instance
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 25));
      final user = userCred.user;
      if (user == null) throw Exception("NO_USER");

      if (!mounted) return;
      widget.onLoggedIn(user.email ?? googleUser.email);
    } on TimeoutException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("タイムアウトしました。もう一度お試しください。")),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyAuthError(e.code))),
      );
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Googleサインイン失敗: ${e.code}")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains("@")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("先にメールアドレスを入力してください。")),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("パスワード再設定メールを送信しました。")),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyAuthError(e.code))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topPad = size.height < 720 ? 18.0 : 36.0;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const _SkyBackground(),
            Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, topPad, 20, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _MascotHeader(),
                      const SizedBox(height: 14),
                      Text(
                        'ログイン',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _FrostCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  hintText: 'メールアドレス',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                                validator: (v) {
                                  final value = (v ?? '').trim();
                                  if (value.isEmpty) return 'メールアドレスを入力してください';
                                  if (!value.contains('@')) return 'メール形式が不正です';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscure,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  hintText: 'パスワード',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  final value = (v ?? '').trim();
                                  if (value.isEmpty) return 'パスワードを入力してください';
                                  if (value.length < 6) return '6文字以上で入力してください';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _GradientPrimaryButton(
                        label: _loading ? 'ログイン中…' : 'ログイン',
                        onPressed: _loading ? null : _emailLogin,
                      ),
                      if (_loading && _progress != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _progress!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: _loading ? null : _forgotPassword,
                          child: const Text('パスワードを忘れた方'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const _OrDivider(label: 'または'),
                      const SizedBox(height: 12),
                      if (isIOS) ...[
                        _SocialButton.apple(
                          onPressed: _loading
                              ? null
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Appleログインは準備中です")),
                                  );
                                },
                        ),
                        const SizedBox(height: 10),
                      ],
                      _SocialButton.google(
                        onPressed: _loading ? null : _googleLogin,
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'アカウントをお持ちでない方は',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            TextButton(
                              onPressed: _loading ? null : _signup,
                              child: const Text('新規登録'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.email, required this.onLogout});

  final String email;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // ログイン済み前提だが念のため
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未ログインです')));
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final mode = _parseUserMode(data?['mode']);

        final tabs = <Widget>[
          _HomeTab(
            email: widget.email,
            mode: mode,
          ),
          _SearchTab(mode: mode),
          _BookingsTab(mode: mode),
          const ChatThreadsPage(),
          _MyPageTab(
            onLogout: widget.onLogout,
          ),
        ];

        final titles = <String>[
          mode == UserMode.worker ? 'ルームサポ（ワーカー）' : 'ルームサポ（依頼者）',
          mode == UserMode.worker ? '案件検索' : '検索',
          mode == UserMode.worker ? '予約管理' : '予約',
          'チャット',
          'マイページ',
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_index]),
            actions: [
              IconButton(
                tooltip: '通知',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsPage()),
                  );
                },
                icon: const Icon(Icons.notifications_none),
              ),
              if (_index == 4)
                TextButton(
                  onPressed: widget.onLogout,
                  child: const Text('ログアウト'),
                ),
            ],
          ),
          body: SafeArea(
            child: IndexedStack(
              index: _index,
              children: tabs,
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'ホーム',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                activeIcon: Icon(Icons.search),
                label: '検索',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event_note_outlined),
                activeIcon: Icon(Icons.event_note),
                label: '予約',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: 'チャット',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'マイページ',
              ),
            ],
          ),
        );
      },
    );
  }
}

enum UserMode { client, worker }

UserMode _parseUserMode(Object? raw) {
  if (raw is String && raw == 'worker') return UserMode.worker;
  return UserMode.client;
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.email, required this.mode});

  final String email;
  final UserMode mode;

  @override
  Widget build(BuildContext context) {
    if (mode == UserMode.worker) {
      return const WorkerHomePane();
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            Icon(
              mode == UserMode.worker
                  ? Icons.handyman_outlined
                  : Icons.home_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              mode == UserMode.worker
                  ? 'ワーカーとして、案件の確認・予約対応・チャットを一個ずつ追加できます。'
                  : '依頼者として、検索・予約・チャットを一個ずつ追加できます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            if (mode == UserMode.client) ...[
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RequestJobPage()),
                  );
                },
                icon: const Icon(Icons.add_task),
                label: const Text('仕事を依頼する'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.confirmation_number_outlined),
                      title: const Text('クーポン'),
                      subtitle: const Text('利用可能なクーポンを確認'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CouponsPage()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final d = snapshot.data?.data();
                          final earnedRaw = d?['stampRallyEarned'];
                          final totalRaw = d?['stampRallyTotal'];
                          final earned =
                              earnedRaw is num ? earnedRaw.toInt() : 0;
                          final total =
                              totalRaw is num ? totalRaw.toInt() : 8;
                          return _StampRallyHomeCard(
                            earned: earned,
                            total: total,
                            onTap: null, // クリックできないようにする
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _StampRallyHomeCard extends StatelessWidget {
  const _StampRallyHomeCard({
    required this.earned,
    required this.total,
    required this.onTap,
  });

  final int earned;
  final int total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = earned.clamp(0, total);
    final progress = total <= 0 ? 0.0 : (done / total);

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.primary.withValues(alpha: 0.10),
            cs.secondary.withValues(alpha: 0.06),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StampRallyBadge(
                icon: Icons.home_rounded,
                color: cs.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'スタンプラリー',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cs.primary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'STAMP RALLY',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.tertiary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ],
                ),
              ),
              _StampRallyBadge(
                icon: Icons.emoji_events_outlined,
                color: cs.tertiary,
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: total,
            itemBuilder: (context, i) {
              final n = i + 1;
              final isDone = n <= done;
              return _StampCircle(
                number: n,
                done: isDone,
              );
            },
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.8),
              valueColor: AlwaysStoppedAnimation(cs.tertiary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '進捗: $done / $total（MVP）',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ゴールでプレゼントGET!',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Icon(Icons.redeem_outlined, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: card,
    );
  }
}

class _StampRallyBadge extends StatelessWidget {
  const _StampRallyBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _StampCircle extends StatelessWidget {
  const _StampCircle({
    required this.number,
    required this.done,
  });

  final int number;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.tertiary;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? accent.withValues(alpha: 0.14) : Colors.transparent,
            border: Border.all(
              color: done ? accent : cs.primary.withValues(alpha: 0.25),
              width: done ? 2 : 2,
            ),
          ),
          child: Center(
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: done
                        ? accent.withValues(alpha: 0.9)
                        : cs.primary.withValues(alpha: 0.55),
                  ),
            ),
          ),
        ),
        if (done)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 12, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

class RequestJobPage extends StatefulWidget {
  const RequestJobPage({super.key});

  @override
  State<RequestJobPage> createState() => _RequestJobPageState();
}

class _RequestJobPageState extends State<RequestJobPage> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();

  String _service = '掃除';
  int _durationMinutes = 120;
  bool _submitting = false;

  static const int _durationMin = 30; // 分
  static const int _durationMax = 480; // 分（8時間）
  static const int _durationStep = 30; // 分刻み

  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);

  // クーポン（任意）
  String? _selectedCouponId;

  String _friendlyRequestError(Object e) {
    // 自前例外（クーポン系）
    final s = e.toString();
    if (s.contains('COUPON_NOT_FOUND')) return 'クーポンが見つかりませんでした。';
    if (s.contains('COUPON_FORBIDDEN')) return 'このクーポンは利用できません。';
    if (s.contains('COUPON_USED')) return 'このクーポンは使用済みです。';
    if (s.contains('COUPON_RESERVED')) return 'このクーポンは他の依頼で予約中です。';
    if (s.contains('COUPON_EXPIRED')) return 'このクーポンは期限切れです。';

    if (e is TimeoutException) {
      return 'タイムアウトしました。通信状況を確認してもう一度お試しください。';
    }

    // Firebase例外
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return '権限がありません（Firestoreルールを確認してください）。';
        case 'unavailable':
          return 'サーバーに接続できません。しばらくして再試行してください。';
        case 'cancelled':
          return '処理がキャンセルされました。';
        case 'aborted':
          return '競合が発生しました。もう一度お試しください。';
        default:
          return '作成に失敗しました（${e.code}）。';
      }
    }

    return '作成に失敗しました。もう一度お試しください。';
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '${minutes}分';
    if (m == 0) return '${h}時間';
    return '${h}時間${m}分';
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;

    if (_toMinutes(_endTime) <= _toMinutes(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('終了時刻は開始時刻より後にしてください')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final jobRef = FirebaseFirestore.instance.collection('jobRequests').doc();
      final now = DateTime.now();

      final jobData = <String, Object?>{
        'clientId': user.uid,
        'service': _service,
        'durationMinutes': _durationMinutes,
        'timeWindow': <String, Object?>{
          'start': _formatTime(_startTime),
          'end': _formatTime(_endTime),
          'startMinutes': _toMinutes(_startTime),
          'endMinutes': _toMinutes(_endTime),
        },
        // 場所入力はMVPでは無し（表示用に固定文を入れる）
        'locationText': '未設定',
        'details': _detailsController.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final couponId = _selectedCouponId;
      if (couponId == null || couponId.isEmpty) {
        await jobRef
            .set(jobData)
            .timeout(const Duration(seconds: 25));
      } else {
        final couponRef =
            FirebaseFirestore.instance.collection('userCoupons').doc(couponId);

        await FirebaseFirestore.instance
            .runTransaction((tx) async {
          final couponSnap = await tx.get(couponRef);
          final c = couponSnap.data();
          if (c == null) throw Exception('COUPON_NOT_FOUND');

          final owner = c['userId'];
          if (owner is! String || owner != user.uid) {
            throw Exception('COUPON_FORBIDDEN');
          }

          // 既に使用済み/予約済み/期限切れなら不可
          if (c['usedAt'] != null) throw Exception('COUPON_USED');
          if (c['reservedJobRequestId'] != null) throw Exception('COUPON_RESERVED');

          final expiresAt = c['expiresAt'];
          if (expiresAt is Timestamp) {
            final dt = expiresAt.toDate();
            if (!dt.isAfter(now)) throw Exception('COUPON_EXPIRED');
          }

          final applied = <String, Object?>{
            'couponId': couponId,
            'title': c['title'] is String ? c['title'] as String : '',
            'description':
                c['description'] is String ? c['description'] as String : '',
            'couponCode':
                c['couponCode'] is String ? c['couponCode'] as String : '',
            'percentOff': c['percentOff'],
            'yenOff': c['yenOff'],
            'source': c['source'],
            'rewardType': c['rewardType'],
            'prizeId': c['prizeId'],
          };

          tx.set(jobRef, <String, Object?>{
            ...jobData,
            'appliedCoupon': applied,
          });

          tx.set(
            couponRef,
            <String, Object?>{
              'reservedAt': FieldValue.serverTimestamp(),
              'reservedJobRequestId': jobRef.id,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        })
            .timeout(const Duration(seconds: 25));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('依頼を作成しました')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyRequestError(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('仕事を依頼する')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '依頼内容',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _service,
                        decoration: const InputDecoration(
                          labelText: 'サービス',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: '掃除', child: Text('掃除')),
                          DropdownMenuItem(value: '家事代行', child: Text('家事代行')),
                          DropdownMenuItem(value: 'ベビー', child: Text('ベビー')),
                          DropdownMenuItem(value: '見守り', child: Text('見守り')),
                          DropdownMenuItem(value: 'ペット', child: Text('ペット')),
                        ],
                        onChanged: _submitting ? null : (v) => setState(() => _service = v ?? _service),
                      ),
                      const SizedBox(height: 10),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '目安時間',
                          prefixIcon: Icon(Icons.schedule),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: '短くする',
                                  onPressed: _submitting
                                      ? null
                                      : () {
                                          setState(() {
                                            _durationMinutes = (_durationMinutes -
                                                    _durationStep)
                                                .clamp(_durationMin, _durationMax);
                                          });
                                        },
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      _formatDuration(_durationMinutes),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '長くする',
                                  onPressed: _submitting
                                      ? null
                                      : () {
                                          setState(() {
                                            _durationMinutes = (_durationMinutes +
                                                    _durationStep)
                                                .clamp(_durationMin, _durationMax);
                                          });
                                        },
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                            Slider(
                              value: _durationMinutes.toDouble(),
                              min: _durationMin.toDouble(),
                              max: _durationMax.toDouble(),
                              divisions:
                                  (_durationMax - _durationMin) ~/ _durationStep,
                              label: _formatDuration(_durationMinutes),
                              onChanged: _submitting
                                  ? null
                                  : (v) {
                                      final snapped =
                                          ((v / _durationStep).round() * _durationStep)
                                              .clamp(_durationMin, _durationMax);
                                      setState(() => _durationMinutes = snapped);
                                    },
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '時間帯',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _submitting
                                    ? null
                                    : () => _pickTime(isStart: true),
                                child: Text('開始 ${_formatTime(_startTime)}'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _submitting
                                    ? null
                                    : () => _pickTime(isStart: false),
                                child: Text('終了 ${_formatTime(_endTime)}'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('userCoupons')
                            .where(
                              'userId',
                              isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                            )
                            .limit(200)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) return const SizedBox.shrink();

                          final now = DateTime.now();
                          final items = snapshot.data?.docs
                                  .map((d) => _UserCoupon.fromDoc(d))
                                  .where((e) => e != null)
                                  .cast<_UserCoupon>()
                                  .where((c) => c.userId == user.uid)
                                  .where((c) => c.usedAt == null)
                                  .where((c) =>
                                      c.expiresAt == null || c.expiresAt!.isAfter(now))
                                  .where((c) => c.reservedJobRequestId == null)
                                  .toList() ??
                              const <_UserCoupon>[];

                          final selected = _selectedCouponId;
                          final selectedCoupon = (selected == null || selected.isEmpty)
                              ? null
                              : items.where((c) => c.id == selected).cast<_UserCoupon?>().firstWhere(
                                    (e) => e != null,
                                    orElse: () => null,
                                  );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                value: (selected == null) ? '' : selected,
                                decoration: const InputDecoration(
                                  labelText: 'クーポン（任意）',
                                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('使わない'),
                                  ),
                                  ...items.map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(
                                        c.expiresAt == null
                                            ? c.title
                                            : '${c.title}（期限: ${c.expiresAt!.toLocal().toString().split(' ').first}）',
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: _submitting
                                    ? null
                                    : (v) => setState(() {
                                          final next = (v ?? '').trim();
                                          _selectedCouponId =
                                              next.isEmpty ? null : next;
                                        }),
                              ),
                              if (selectedCoupon != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Text(
                                    selectedCoupon.description,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                            ],
                          );
                        },
                      ),
                      TextFormField(
                        controller: _detailsController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: '詳細',
                          hintText: '例: 掃除してほしい範囲、注意点など',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: Text(_submitting ? '作成中…' : '依頼を作成'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '※ まずは依頼を作るだけの最小版です。次に日程指定/料金/マッチングを追加できます。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CouponsPage extends StatelessWidget {
  const CouponsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未ログインです')));
    }

    final stream = FirebaseFirestore.instance
        .collection('userCoupons')
        .where('userId', isEqualTo: user.uid)
        .limit(200) // 並びはアプリ側でソート（インデックス回避）
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('クーポン'),
        actions: [
          IconButton(
            tooltip: 'ルーレット',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StampRallyPage()),
              );
            },
            icon: const Icon(Icons.casino_outlined),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('読み込みに失敗しました'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!.docs
              .map((d) => _UserCoupon.fromDoc(d))
              .where((e) => e != null)
              .cast<_UserCoupon>()
              .toList();

          items.sort((a, b) {
            final aTs = a.createdAt;
            final bTs = b.createdAt;
            if (aTs != null && bTs != null) return bTs.compareTo(aTs);
            if (aTs != null) return -1;
            if (bTs != null) return 1;
            return 0;
          });

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('クーポンがまだありません。'),
                    const SizedBox(height: 8),
                    const Text('スタンプラリーのルーレットでGETできます。'),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StampRallyPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.casino_outlined),
                      label: const Text('ルーレットを見る'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final c = items[idx];
              return Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.confirmation_number_outlined,
                              color: Theme.of(context).colorScheme.tertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: c.usedAt == null
                                  ? Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withValues(alpha: 0.14)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              c.usedAt == null ? '未使用' : '使用済み',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'コード: ${c.couponCode}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const Spacer(),
                          Text(
                            c.expiresAt == null
                                ? '期限: —'
                                : '期限: ${c.expiresAt!.toLocal().toString().split(' ').first}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('お知らせ')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('お知らせ（準備中）'),
        ),
      ),
    );
  }
}

class StampRallyPage extends StatefulWidget {
  const StampRallyPage({super.key});

  @override
  State<StampRallyPage> createState() => _StampRallyPageState();
}

class _StampRallyPageState extends State<StampRallyPage> {
  bool _granting = false;

  Future<void> _grantStamp() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_granting) return;

    setState(() => _granting = true);
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final d = snap.data() ?? <String, dynamic>{};
        final earnedRaw = d['stampRallyEarned'];
        final totalRaw = d['stampRallyTotal'];
        final earned = earnedRaw is num ? earnedRaw.toInt() : 0;
        final total = totalRaw is num ? totalRaw.toInt() : 8;
        if (earned >= total) return;

        tx.set(
          userRef,
          <String, Object?>{
            'stampRallyEarned': earned + 1,
            'stampRallyTotal': total,
            'stampRallyUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('スタンプを付与しました')),
      );
    } finally {
      if (mounted) setState(() => _granting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未ログインです')));
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('スタンプラリー')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'プレゼント内容は「クーポン」です。\nルーレットでクーポン内容が決まります。',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: userRef.snapshots(),
                builder: (context, snapshot) {
                  final d = snapshot.data?.data();
                  final earnedRaw = d?['stampRallyEarned'];
                  final totalRaw = d?['stampRallyTotal'];
                  final earned =
                      earnedRaw is num ? earnedRaw.toInt() : 0;
                  final total = totalRaw is num ? totalRaw.toInt() : 8;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '現在のスタンプ',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$earned / $total',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _granting ? null : _grantStamp,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(_granting ? '付与中…' : 'スタンプを付与（MVP）'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '※ 本番では「予約完了」などのイベントに連動して自動付与します。今は動作確認用です。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          const CouponRouletteCard(),
        ],
      ),
    );
  }
}

class _UserCoupon {
  _UserCoupon({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.couponCode,
    this.percentOff,
    this.yenOff,
    this.createdAt,
    this.expiresAt,
    this.usedAt,
    this.reservedJobRequestId,
  });

  final String id;
  final String userId;
  final String title;
  final String description;
  final String couponCode;
  final int? percentOff;
  final int? yenOff;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final String? reservedJobRequestId;

  static _UserCoupon? fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final userId = d['userId'];
    final title = d['title'];
    final description = d['description'];
    final couponCode = d['couponCode'];
    if (userId is! String ||
        title is! String ||
        description is! String ||
        couponCode is! String) {
      return null;
    }
    final expiresAt = d['expiresAt'] is Timestamp
        ? (d['expiresAt'] as Timestamp).toDate()
        : null;
    final createdAt = d['createdAt'] is Timestamp
        ? (d['createdAt'] as Timestamp).toDate()
        : null;
    final usedAt =
        d['usedAt'] is Timestamp ? (d['usedAt'] as Timestamp).toDate() : null;
    final reservedJobRequestId = d['reservedJobRequestId'] is String
        ? d['reservedJobRequestId'] as String
        : null;

    final percentOff = d['percentOff'] is num ? (d['percentOff'] as num).toInt() : null;
    final yenOff = d['yenOff'] is num ? (d['yenOff'] as num).toInt() : null;
    return _UserCoupon(
      id: doc.id,
      userId: userId,
      title: title,
      description: description,
      couponCode: couponCode,
      percentOff: percentOff,
      yenOff: yenOff,
      createdAt: createdAt,
      expiresAt: expiresAt,
      usedAt: usedAt,
      reservedJobRequestId: reservedJobRequestId,
    );
  }
}

class _SearchTab extends StatelessWidget {
  const _SearchTab({required this.mode});

  final UserMode mode;

  @override
  Widget build(BuildContext context) {
    if (mode == UserMode.client) {
      return const WorkerSearchTab();
    }
    if (mode == UserMode.worker) {
      return const WorkerJobsTab();
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          mode == UserMode.worker ? '案件検索（準備中）' : '検索（準備中）',
        ),
      ),
    );
  }
}

class _BookingsTab extends StatelessWidget {
  const _BookingsTab({required this.mode});

  final UserMode mode;

  @override
  Widget build(BuildContext context) {
    if (mode == UserMode.worker) {
      return const WorkerBookingsTab();
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const Material(
            color: Colors.transparent,
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: '予約一覧'),
                Tab(text: '定期予約'),
                Tab(text: 'ご利用履歴'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _BookingsListPane(
                  title: '予約一覧',
                  message: 'これから予約一覧を表示します。',
                ),
                _BookingsListPane(
                  title: '定期予約',
                  message: '週次・隔週などの定期予約を管理します。',
                ),
                _BookingsListPane(
                  title: 'ご利用履歴',
                  message: '過去のご利用履歴を表示します。',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingsListPane extends StatelessWidget {
  const _BookingsListPane({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('（準備中）'),
          ),
        ),
      ],
    );
  }
}

class _MyPageTab extends StatelessWidget {
  const _MyPageTab({required this.onLogout});

  final VoidCallback onLogout;

  Widget _starsRow(BuildContext context, double rating) {
    final cs = Theme.of(context).colorScheme;
    final r = rating.clamp(0.0, 5.0);
    final full = r.floor();
    final hasHalf = (r - full) >= 0.5;
    final empty = 5 - full - (hasHalf ? 1 : 0);

    final icons = <Widget>[
      for (var i = 0; i < full; i++)
        Icon(Icons.star, size: 18, color: cs.tertiary),
      if (hasHalf) Icon(Icons.star_half, size: 18, color: cs.tertiary),
      for (var i = 0; i < empty; i++)
        Icon(Icons.star_border, size: 18, color: cs.outline),
    ];

    return Row(children: icons);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('未ログインです'));
    }
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final workerRef = FirebaseFirestore.instance.collection('workers').doc(user.uid);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                UserAvatar(userRef: userRef, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.displayName?.trim().isNotEmpty == true
                                  ? user.displayName!
                                  : 'ユーザー',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'プロフィール編集',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ProfileEditPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email ?? '（メール未設定）',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'アイコン変更',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AvatarPickerPage()),
                    );
                  },
                  icon: const Icon(Icons.image_outlined),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RatingsPage()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: workerRef.snapshots(),
                builder: (context, snapshot) {
                  final d = snapshot.data?.data();
                  final rating = d?['rating'];
                  final ratingCount = d?['ratingCount'];

                  final ratingVal = rating is num ? rating.toDouble() : null;
                  final countVal =
                      ratingCount is num ? ratingCount.toInt() : 0;

                  return Row(
                    children: [
                      const Icon(Icons.star_outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '評価',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            if (ratingVal == null || countVal <= 0) ...[
                              Text(
                                'まだ評価がありません',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  _starsRow(context, ratingVal),
                                  const SizedBox(width: 8),
                                  Text(
                                    ratingVal.toStringAsFixed(1),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '($countVal件)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userRef.snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final modeRaw = data?['mode'];
            final mode = modeRaw is String ? modeRaw : 'client';
            final isWorker = mode == 'worker';

            Future<void> setMode(String next) async {
              await userRef.set(
                <String, Object?>{
                  'mode': next,
                  'updatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
              );
            }

            return Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'モード切り替え',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isWorker ? '現在: ワーカー' : '現在: 依頼者',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () async {
                        if (isWorker) {
                          await setMode('client');
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('依頼者に切り替えました')),
                          );
                          return;
                        }

                        // 依頼者 → ワーカー：未登録なら登録ウィザードへ
                        final workerRef = FirebaseFirestore.instance
                            .collection('workers')
                            .doc(user.uid);
                        final workerSnap = await workerRef.get();
                        final workerData = workerSnap.data();
                        final onboardingDone =
                            workerData?['onboardingComplete'] == true;

                        if (!onboardingDone) {
                          final ok = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => const WorkerSignupWizardPage(),
                            ),
                          );
                          if (ok != true) return;
                        }

                        await setMode('worker');
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ワーカーに切り替えました')),
                        );
                      },
                      child: Text(
                        isWorker ? '依頼者に切り替える' : 'ワーカーに切り替える',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '※ この設定はアカウントに保存されます。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SkyBackground extends StatelessWidget {
  const _SkyBackground();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.primary.withValues(alpha: 0.10),
            cs.secondary.withValues(alpha: 0.08),
            Colors.white,
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _MascotHeader extends StatelessWidget {
  const _MascotHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 6),
        Image.asset(
          'assets/images/1.png',
          height: 150,
          fit: BoxFit.contain,
          // 画像が無い場合でも「白い背景」は出さない
          errorBuilder: (_, __, ___) => SizedBox(
            height: 150,
            width: 150,
            child: Center(
              child: Icon(
                Icons.home_rounded,
                size: 84,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
            children: [
              TextSpan(
                text: 'ルーム',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              TextSpan(
                text: 'サポ',
                style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FrostCard extends StatelessWidget {
  const _FrostCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GradientPrimaryButton extends StatelessWidget {
  const _GradientPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: onPressed == null
              ? [Colors.grey.shade300, Colors.grey.shade400]
              : [cs.secondary, cs.primary],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outlineVariant, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Expanded(child: Divider(color: cs.outlineVariant, thickness: 1)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton._({
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.label,
    required this.leading,
    this.border,
  });

  factory _SocialButton.apple({required VoidCallback? onPressed}) {
    return _SocialButton._(
      onPressed: onPressed,
      background: const Color(0xFF111827),
      foreground: Colors.white,
      label: 'Appleで続行',
      leading: const Icon(Icons.apple, color: Colors.white),
    );
  }

  factory _SocialButton.google({required VoidCallback? onPressed}) {
    return _SocialButton._(
      onPressed: onPressed,
      background: Colors.white.withValues(alpha: 0.75),
      foreground: const Color(0xFF1F2937),
      border: null,
      label: 'Googleで続行',
      leading: const Icon(Icons.g_mobiledata, color: Color(0xFF4285F4), size: 28),
    );
  }

  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final BorderSide? border;
  final String label;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: border,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

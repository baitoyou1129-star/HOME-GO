import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'worker_signup_page.dart';

class WorkerSignupStartPage extends StatefulWidget {
  const WorkerSignupStartPage({
    super.key,
    required this.onSignedUp,
    this.initialEmail,
  });

  final ValueChanged<String> onSignedUp;
  final String? initialEmail;

  @override
  State<WorkerSignupStartPage> createState() => _WorkerSignupStartPageState();
}

class _WorkerSignupStartPageState extends State<WorkerSignupStartPage> {
  final _formKey = GlobalKey<FormState>();
  final _legalNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _password2Controller = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _obscure2 = true;

  @override
  void initState() {
    super.initState();
    _emailController.text = (widget.initialEmail ?? '').trim();
  }

  @override
  void dispose() {
    _legalNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
    super.dispose();
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'このメールアドレスは既に使われています。';
      case 'invalid-email':
        return 'メール形式が不正です。';
      case 'weak-password':
        return 'パスワードが弱すぎます（6文字以上にしてください）。';
      case 'operation-not-allowed':
        return 'このログイン方法が無効です（Firebase設定を確認してください）。';
      default:
        return '登録に失敗しました（$code）';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final legalName = _legalNameController.text.trim();
      final phone = _phoneController.text.trim();

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) throw Exception('NO_USER');

      await user.updateDisplayName(legalName);

      final usersRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await usersRef.set(
        <String, Object?>{
          'mode': 'worker',
          'displayName': legalName,
          'phone': phone,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      // ここからSTEP1〜5の登録へ
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const WorkerSignupWizardPage(),
        ),
      );

      // 完了でも中断でも、ログイン状態にはなるのでホームへ進める
      widget.onSignedUp(email);

      if (!mounted) return;
      if (ok != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ワーカー登録は後で続きから再開できます')),
        );
      }
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyAuthError(e.code))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ワーカー新規登録')),
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
                        'STEP 1：基本情報',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _legalNameController,
                        decoration: const InputDecoration(
                          hintText: '名前（本名）',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return '名前を入力してください';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
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
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          hintText: 'パスワード（6文字以上）',
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
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _password2Controller,
                        obscureText: _obscure2,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          hintText: 'パスワード（確認）',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure2 = !_obscure2),
                            icon: Icon(
                              _obscure2
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return '確認用パスワードを入力してください';
                          if (value != _passwordController.text) {
                            return 'パスワードが一致しません';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(
                          hintText: '電話番号（SMS認証）',
                          prefixIcon: Icon(Icons.call_outlined),
                        ),
                        validator: (v) {
                          final raw = (v ?? '').trim();
                          if (raw.isEmpty) return '電話番号を入力してください';
                          final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
                          if (digits.length < 10) return '電話番号が短すぎます';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: Text(_loading ? '作成中…' : '次へ（プロフィール登録）'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '※ 次の画面でプロフィール/本人確認/料金/振込先/資格を登録します。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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


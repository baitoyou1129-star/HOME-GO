import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClientSignupPage extends StatefulWidget {
  const ClientSignupPage({
    super.key,
    required this.onSignedUp,
    this.initialEmail,
  });

  final ValueChanged<String> onSignedUp;
  final String? initialEmail;

  @override
  State<ClientSignupPage> createState() => _ClientSignupPageState();
}

class _ClientSignupPageState extends State<ClientSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _buildingController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _password2Controller = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _obscure2 = true;
  final Set<String> _purposes = <String>{};

  @override
  void initState() {
    super.initState();
    _emailController.text = (widget.initialEmail ?? '').trim();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _addressLine1Controller.dispose();
    _buildingController.dispose();
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
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final postalCode = _postalCodeController.text.trim();
      final city = _cityController.text.trim();
      final addressLine1 = _addressLine1Controller.text.trim();
      final building = _buildingController.text.trim();

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) throw Exception('NO_USER');

      await user.updateDisplayName(name);

      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await ref.set(
        <String, Object?>{
          'mode': 'client',
          'displayName': name,
          'phone': phone,
          'purposes': _purposes.toList()..sort(),
          'address': <String, Object?>{
            'postalCode': postalCode,
            'city': city,
            'line1': addressLine1,
            'building': building,
          },
          'onboarding': <String, Object?>{
            'addressCompleted': city.isNotEmpty,
            'paymentCompleted': false,
            'kycCompleted': false,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      widget.onSignedUp(email);
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyAuthError(e.code))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登録に失敗しました。もう一度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('依頼者登録')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: '① 基本情報（必須）',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: '名前（ニックネームOK）',
                            prefixIcon: Icon(Icons.person_outline),
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
                              onPressed: () =>
                                  setState(() => _obscure2 = !_obscure2),
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
                            hintText: '電話番号（SMS認証用）',
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
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '※ SMS認証は後で追加できます（今回は番号の登録まで）。',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '② 住所情報（後でもOK）',
                    subtitle: '最初は「市区町村だけ」でもOKです。',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _postalCodeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '郵便番号（任意）',
                            prefixIcon: Icon(Icons.local_post_office_outlined),
                          ),
                          validator: (v) {
                            final raw = (v ?? '').trim();
                            if (raw.isEmpty) return null;
                            final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
                            if (digits.length != 7) return '郵便番号は7桁で入力してください';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            hintText: '市区町村（任意）',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _addressLine1Controller,
                          decoration: const InputDecoration(
                            hintText: '番地（後で入力可）',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _buildingController,
                          decoration: const InputDecoration(
                            hintText: '建物名（任意）',
                            prefixIcon: Icon(Icons.apartment_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '③ 利用目的（任意）',
                    subtitle: '複数選択できます。',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        '掃除',
                        '家事代行',
                        '見守り',
                        'ペット',
                        'その他',
                      ].map((label) {
                        final selected = _purposes.contains(label);
                        return FilterChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: _loading
                              ? null
                              : (v) {
                                  setState(() {
                                    if (v) {
                                      _purposes.add(label);
                                    } else {
                                      _purposes.remove(label);
                                    }
                                  });
                                },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SectionCard(
                    title: '④ 支払い方法（後で登録）',
                    subtitle: '初回登録ではスキップできます。',
                    child: Column(
                      children: [
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.credit_card_outlined),
                          title: Text('クレカ'),
                          subtitle: Text('後で登録できます'),
                        ),
                        Divider(height: 1),
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.apple),
                          title: Text('Apple Pay'),
                          subtitle: Text('後で登録できます'),
                        ),
                        Divider(height: 1),
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.g_mobiledata),
                          title: Text('Google Pay'),
                          subtitle: Text('後で登録できます'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SectionCard(
                    title: '⑤ 本人確認（後で）',
                    subtitle: '信頼度アップ用。初回はスキップできます。',
                    child: Column(
                      children: [
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.badge_outlined),
                          title: Text('身分証アップロード'),
                          subtitle: Text('後で登録できます'),
                        ),
                        Divider(height: 1),
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.face_outlined),
                          title: Text('顔写真確認'),
                          subtitle: Text('後で登録できます'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_loading ? '登録中…' : '登録する'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '※ 登録後に「マイページ」からワーカーへ切り替えもできます。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}


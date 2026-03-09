import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _buildingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _addressLine1Controller.dispose();
    _buildingController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    final d = snap.data();

    final displayName =
        (d?['displayName'] is String) ? d!['displayName'] as String : null;
    final phone = (d?['phone'] is String) ? d!['phone'] as String : null;
    final address = (d?['address'] is Map)
        ? (d!['address'] as Map).cast<String, Object?>()
        : const <String, Object?>{};

    _displayNameController.text =
        (displayName?.trim().isNotEmpty == true) ? displayName!.trim() : (user.displayName ?? '');
    _phoneController.text = phone?.trim() ?? '';
    _postalCodeController.text =
        (address['postalCode'] is String) ? (address['postalCode'] as String) : '';
    _cityController.text =
        (address['city'] is String) ? (address['city'] as String) : '';
    _addressLine1Controller.text =
        (address['line1'] is String) ? (address['line1'] as String) : '';
    _buildingController.text =
        (address['building'] is String) ? (address['building'] as String) : '';

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final displayName = _displayNameController.text.trim();
      final phone = _phoneController.text.trim();
      final postalCode = _postalCodeController.text.trim();
      final city = _cityController.text.trim();
      final line1 = _addressLine1Controller.text.trim();
      final building = _buildingController.text.trim();

      // Auth側の表示名も更新（マイページ表示が揃う）
      if (displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
      }

      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await ref.set(
        <String, Object?>{
          'displayName': displayName,
          'phone': phone,
          'address': <String, Object?>{
            'postalCode': postalCode,
            'city': city,
            'line1': line1,
            'building': building,
          },
          'onboarding': <String, Object?>{
            'addressCompleted': city.isNotEmpty,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存しました')),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未ログインです')));
    }

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール編集')),
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
                        '基本情報',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'ニックネーム',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'ニックネームを入力してください';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: user.email ?? '',
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'メールアドレス',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: '電話番号',
                          prefixIcon: Icon(Icons.call_outlined),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '住所（任意）',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _postalCodeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '郵便番号',
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
                          labelText: '市区町村',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _addressLine1Controller,
                        decoration: const InputDecoration(
                          labelText: '番地',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _buildingController,
                        decoration: const InputDecoration(
                          labelText: '建物名（任意）',
                          prefixIcon: Icon(Icons.apartment_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? '保存中…' : '保存'),
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


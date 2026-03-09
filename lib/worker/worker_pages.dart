import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frotter/notifications/notifications_page.dart';
import 'package:frotter/worker/job_search.dart';

class WorkerHomePane extends StatelessWidget {
  const WorkerHomePane({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('未ログインです'));
    }

    final statsRef =
        FirebaseFirestore.instance.collection('workerStats').doc(user.uid);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ワーカー',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user.email ?? '',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '通知',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NotificationsPage()),
                        );
                      },
                      icon: const Icon(Icons.notifications_none),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: statsRef.snapshots(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data() ?? const <String, dynamic>{};
                    final todayBookings = data['todayBookingsCount'] is num
                        ? (data['todayBookingsCount'] as num).toInt()
                        : 0;
                    final newRequests = data['newRequestsCount'] is num
                        ? (data['newRequestsCount'] as num).toInt()
                        : 0;
                    final monthEarnings = data['monthEarningsYen'] is num
                        ? (data['monthEarningsYen'] as num).toInt()
                        : 0;

                    return Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: '今日の予約',
                            value: '$todayBookings件',
                            icon: Icons.today_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            title: '新着依頼',
                            value: '$newRequests件',
                            icon: Icons.notifications_active_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            title: '今月の報酬',
                            value: '¥$monthEarnings',
                            icon: Icons.payments_outlined,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WorkerProfilePage()),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('プロフィールを編集'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Column(
            children: const [
              ListTile(
                leading: Icon(Icons.search),
                title: Text('案件検索'),
                subtitle: Text('下の「検索」タブから確認できます'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.event_note_outlined),
                title: Text('予約管理'),
                subtitle: Text('下の「予約」タブから確認できます'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class WorkerJobsTab extends StatelessWidget {
  const WorkerJobsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const WorkerJobSearchTab();
  }
}

class WorkerBookingsTab extends StatelessWidget {
  const WorkerBookingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('予約管理（準備中）'),
      ),
    );
  }
}

class WorkerProfilePage extends StatefulWidget {
  const WorkerProfilePage({super.key});

  @override
  State<WorkerProfilePage> createState() => _WorkerProfilePageState();
}

class _WorkerProfilePageState extends State<WorkerProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _areaController = TextEditingController();
  final _priceController = TextEditingController();

  final Set<String> _services = <String>{};
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _areaController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance.collection('workers').doc(user.uid);
    final snap = await ref.get();
    final d = snap.data();
    if (d != null) {
      final displayName = d['displayName'];
      final area = d['areaText'];
      final price = d['priceYenPerHour'];
      final services = d['services'];
      final active = d['isActive'];

      if (displayName is String) _displayNameController.text = displayName;
      if (area is String) _areaController.text = area;
      if (price is num) _priceController.text = price.toInt().toString();
      if (services is List) {
        _services
          ..clear()
          ..addAll(services.whereType<String>());
      }
      if (active is bool) _isActive = active;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final price = int.tryParse(_priceController.text.trim());
      final ref = FirebaseFirestore.instance.collection('workers').doc(user.uid);
      await ref.set(
        <String, Object?>{
          'displayName': _displayNameController.text.trim(),
          'areaText': _areaController.text.trim(),
          'services': _services.toList(),
          'priceYenPerHour': price,
          'isActive': _isActive,
          // ソート用の更新時刻
          'updatedAt': FieldValue.serverTimestamp(),
          // MVP: ひとまず0、後で利用数などで算出
          'heatScore': 0,
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    const serviceOptions = <String>[
      '掃除',
      '家事代行',
      'ベビー',
      '見守り',
      'ペット',
      '買い物',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ワーカープロフィール'),
      ),
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
                        '検索に表示する情報',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: '表示名',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return '表示名を入力してください';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _areaController,
                        decoration: const InputDecoration(
                          labelText: 'エリア',
                          hintText: '例: 大阪市 / 渋谷区',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '料金（円/時間）',
                          hintText: '例: 3000',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '提供サービス',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: serviceOptions.map((s) {
                          final on = _services.contains(s);
                          return FilterChip(
                            label: Text(s),
                            selected: on,
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _services.add(s);
                                } else {
                                  _services.remove(s);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        title: const Text('検索に表示する'),
                        subtitle: const Text('OFFにすると検索から非表示になります'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 12),
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


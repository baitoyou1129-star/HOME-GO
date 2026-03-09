import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RatingsPage extends StatefulWidget {
  const RatingsPage({super.key});

  @override
  State<RatingsPage> createState() => _RatingsPageState();
}

class _RatingsPageState extends State<RatingsPage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未ログインです')));
    }

    // 自分に関係する評価だけ読む（ルール厳しめでも動く）
    final givenStream = FirebaseFirestore.instance
        .collection('ratings')
        .where('raterId', isEqualTo: user.uid)
        .limit(200)
        .snapshots();
    final receivedStream = FirebaseFirestore.instance
        .collection('ratings')
        .where('targetWorkerId', isEqualTo: user.uid)
        .limit(200)
        .snapshots();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('評価'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '投稿した評価'),
              Tab(text: '受け取った評価'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddRatingPage()),
            );
          },
          icon: const Icon(Icons.rate_review_outlined),
          label: const Text('評価を登録'),
        ),
        body: TabBarView(
          children: [
            _RatingsStreamList(
              stream: givenStream,
              emptyText: 'まだ評価を投稿していません。',
            ),
            _RatingsStreamList(
              stream: receivedStream,
              emptyText: 'まだ評価を受け取っていません。',
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingsStreamList extends StatelessWidget {
  const _RatingsStreamList({
    required this.stream,
    required this.emptyText,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('読み込みに失敗しました'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!.docs
            .map((d) => _Rating.fromDoc(d))
            .where((e) => e != null)
            .cast<_Rating>()
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
              child: Text(emptyText),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 84),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final r = items[idx];
            return Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${r.stars}.0',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          r.createdAt == null
                              ? '—'
                              : r.createdAt!.toLocal().toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (r.comment.isEmpty) ? '（コメントなし）' : r.comment,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ワーカー: ${r.targetWorkerName.isEmpty ? r.targetWorkerId : r.targetWorkerName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AddRatingPage extends StatefulWidget {
  const AddRatingPage({super.key});

  @override
  State<AddRatingPage> createState() => _AddRatingPageState();
}

class _AddRatingPageState extends State<AddRatingPage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  String? _targetWorkerId;
  String _targetWorkerName = '';
  int _stars = 5;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;
    final targetId = _targetWorkerId;
    if (targetId == null || targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ワーカーを選択してください')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final now = FieldValue.serverTimestamp();
      final ratingsRef = FirebaseFirestore.instance.collection('ratings');
      final workerRef =
          FirebaseFirestore.instance.collection('workers').doc(targetId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final workerSnap = await tx.get(workerRef);
        final d = workerSnap.data();
        final oldCount =
            (d != null && d['ratingCount'] is num) ? (d['ratingCount'] as num).toInt() : 0;
        final oldTotal =
            (d != null && d['ratingTotal'] is num) ? (d['ratingTotal'] as num).toDouble() : 0.0;

        final newCount = oldCount + 1;
        final newTotal = oldTotal + _stars.toDouble();
        final newAvg = newTotal / newCount;

        final ratingDoc = ratingsRef.doc();
        tx.set(ratingDoc, <String, Object?>{
          'raterId': user.uid,
          'raterName': user.displayName ?? '',
          'targetWorkerId': targetId,
          'targetWorkerName': _targetWorkerName,
          'stars': _stars,
          'comment': _commentController.text.trim(),
          'createdAt': now,
          'updatedAt': now,
        });

        tx.set(workerRef, <String, Object?>{
          'ratingCount': newCount,
          'ratingTotal': newTotal,
          'rating': double.parse(newAvg.toStringAsFixed(2)),
          'updatedAt': now,
        }, SetOptions(merge: true));
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('評価を登録しました')),
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

    final workersStream = FirebaseFirestore.instance
        .collection('workers')
        .orderBy('updatedAt', descending: true)
        .limit(80)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('評価を登録')),
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
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: workersStream,
                        builder: (context, snapshot) {
                          final items = <DropdownMenuItem<String>>[
                            const DropdownMenuItem(
                              value: '',
                              child: Text('選択してください'),
                            ),
                          ];
                          if (snapshot.hasData) {
                            for (final d in snapshot.data!.docs) {
                              final data = d.data();
                              final name = data['displayName'] is String
                                  ? data['displayName'] as String
                                  : d.id;
                              final area = data['areaText'] is String
                                  ? data['areaText'] as String
                                  : '';
                              items.add(
                                DropdownMenuItem(
                                  value: d.id,
                                  child: Text(area.isEmpty ? name : '$name（$area）'),
                                ),
                              );
                            }
                          }

                          return DropdownButtonFormField<String>(
                            value: _targetWorkerId ?? '',
                            items: items,
                            decoration: const InputDecoration(
                              labelText: 'ワーカー',
                              prefixIcon: Icon(Icons.person_search_outlined),
                            ),
                            onChanged: _saving
                                ? null
                                : (v) {
                                    final next = (v ?? '').trim();
                                    if (next.isEmpty) {
                                      setState(() {
                                        _targetWorkerId = null;
                                        _targetWorkerName = '';
                                      });
                                      return;
                                    }
                                    final doc = snapshot.data?.docs
                                        .firstWhere((e) => e.id == next);
                                    final name = doc?.data()['displayName'] is String
                                        ? doc!.data()['displayName'] as String
                                        : '';
                                    setState(() {
                                      _targetWorkerId = next;
                                      _targetWorkerName = name;
                                    });
                                  },
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return 'ワーカーを選択してください';
                              return null;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '評価（1〜5）',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (i) {
                          final v = i + 1;
                          final on = v <= _stars;
                          return IconButton(
                            onPressed: _saving ? null : () => setState(() => _stars = v),
                            icon: Icon(
                              on ? Icons.star : Icons.star_border,
                              color: on
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          );
                        }),
                      ),
                      TextFormField(
                        controller: _commentController,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          labelText: 'コメント（任意）',
                          prefixIcon: Icon(Icons.chat_bubble_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? '登録中…' : '登録する'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '※ MVP: 予約完了後のみ投稿、などの制限は後で追加できます。',
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

class _Rating {
  _Rating({
    required this.id,
    required this.raterId,
    required this.targetWorkerId,
    required this.stars,
    required this.comment,
    required this.targetWorkerName,
    this.createdAt,
  });

  final String id;
  final String raterId;
  final String targetWorkerId;
  final int stars;
  final String comment;
  final String targetWorkerName;
  final DateTime? createdAt;

  static _Rating? fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final raterId = d['raterId'];
    final targetWorkerId = d['targetWorkerId'];
    final stars = d['stars'];
    if (raterId is! String || targetWorkerId is! String || stars is! num) {
      return null;
    }
    final comment = d['comment'] is String ? d['comment'] as String : '';
    final targetWorkerName =
        d['targetWorkerName'] is String ? d['targetWorkerName'] as String : '';
    final createdAt =
        d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null;
    return _Rating(
      id: doc.id,
      raterId: raterId,
      targetWorkerId: targetWorkerId,
      stars: stars.toInt(),
      comment: comment,
      targetWorkerName: targetWorkerName,
      createdAt: createdAt,
    );
  }
}


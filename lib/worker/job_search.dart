import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum JobSort { newest, distance }

class WorkerJobSearchTab extends StatefulWidget {
  const WorkerJobSearchTab({super.key});

  @override
  State<WorkerJobSearchTab> createState() => _WorkerJobSearchTabState();
}

class _WorkerJobSearchTabState extends State<WorkerJobSearchTab> {
  final _queryController = TextEditingController();

  JobSort _sort = JobSort.newest;
  final Set<String> _services = <String>{};
  int? _durationMin;
  int? _durationMax;

  // 距離順のための簡易現在地（手入力）
  double? _lat;
  double? _lng;

  final Set<String> _appliedJobIds = <String>{};
  final Map<String, bool> _applyingByJobId = <String, bool>{};

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _applyToJob(JobRequestCardData job) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    if (_appliedJobIds.contains(job.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この依頼には応募済みです')),
      );
      return;
    }

    if (_applyingByJobId[job.id] == true) return;
    setState(() => _applyingByJobId[job.id] = true);

    try {
      final jobRef =
          FirebaseFirestore.instance.collection('jobRequests').doc(job.id);
      final appId = '${job.id}_${user.uid}';
      final appRef =
          FirebaseFirestore.instance.collection('jobApplications').doc(appId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final jobSnap = await tx.get(jobRef);
        final jobData = jobSnap.data();
        if (jobData == null) throw Exception('JOB_NOT_FOUND');
        final status = jobData['status'];
        if (status is String && status != 'open') {
          throw Exception('JOB_CLOSED');
        }

        final appSnap = await tx.get(appRef);
        if (appSnap.exists) {
          throw Exception('ALREADY_APPLIED');
        }

        final clientId = jobData['clientId'];
        final service = jobData['service'];
        final duration = jobData['durationMinutes'];

        tx.set(appRef, <String, Object?>{
          'jobRequestId': job.id,
          'workerId': user.uid,
          'clientId': clientId is String ? clientId : null,
          'service': service is String ? service : job.service,
          'durationMinutes': duration is num ? duration.toInt() : job.durationMinutes,
          'status': 'applied',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      setState(() => _appliedJobIds.add(job.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('応募しました')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('ALREADY_APPLIED')
          ? 'この依頼には応募済みです'
          : e.toString().contains('JOB_CLOSED')
              ? 'この依頼は受付終了です'
              : e.toString().contains('permission-denied')
                  ? '権限がありません（Firestoreルールを確認してください）'
                  : '応募に失敗しました';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) {
        setState(() => _applyingByJobId.remove(job.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // インデックス地獄を避けるため、MVPはまとめて取ってアプリ側で絞る
    final baseQuery = FirebaseFirestore.instance
        .collection('jobRequests')
        .orderBy('updatedAt', descending: true)
        .limit(200);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Material(
            color: Colors.transparent,
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: '依頼一覧'),
                Tab(text: 'サービス別検索'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildList(context, baseQuery, showServiceChips: false),
                _buildList(context, baseQuery, showServiceChips: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    Query<Map<String, dynamic>> baseQuery, {
    required bool showServiceChips,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            children: [
              TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: '依頼を検索（場所・詳細）',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _queryController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _queryController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<JobSort>(
                      segments: const [
                        ButtonSegment(
                          value: JobSort.newest,
                          label: Text('新着'),
                          icon: Icon(Icons.fiber_new_outlined),
                        ),
                        ButtonSegment(
                          value: JobSort.distance,
                          label: Text('距離順'),
                          icon: Icon(Icons.near_me_outlined),
                        ),
                      ],
                      selected: {_sort},
                      onSelectionChanged: (v) {
                        setState(() => _sort = v.first);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _openFilterSheet(context),
                    icon: const Icon(Icons.tune),
                    label: const Text('フィルター'),
                  ),
                ],
              ),
              if (_sort == JobSort.distance && (_lat == null || _lng == null))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '距離順は「フィルター」で現在地(緯度/経度)を入力すると有効になります。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                ),
              if (showServiceChips) ...[
                const SizedBox(height: 10),
                _ServiceQuickChips(
                  selected: _services,
                  onToggle: (s) {
                    setState(() {
                      if (_services.contains(s)) {
                        _services.remove(s);
                      } else {
                        _services.add(s);
                      }
                    });
                  },
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: baseQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('読み込みに失敗しました'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = snapshot.data!.docs
                  .map((d) => JobRequestCardData.fromDoc(d))
                  .where((e) => e != null)
                  .cast<JobRequestCardData>()
                  .toList();

              final filtered = _applyFilterAndSort(items);
              if (filtered.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('条件に合う依頼が見つかりませんでした。'),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final r = filtered[idx];
                  final applied = _appliedJobIds.contains(r.id);
                  final applying = _applyingByJobId[r.id] == true;
                  final distanceKm = (_lat != null &&
                          _lng != null &&
                          r.lat != null &&
                          r.lng != null)
                      ? haversineKm(_lat!, _lng!, r.lat!, r.lng!)
                      : null;

                  return Card(
                    elevation: 0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => JobRequestDetailsPage(jobId: r.id),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  child: Icon(Icons.work_outline),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.service,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        r.locationText,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.grey.shade700),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${r.durationMinutes}分',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      distanceKm == null
                                          ? '距離 —'
                                          : '距離 ${distanceKm.toStringAsFixed(1)}km',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              r.details.isEmpty ? '（詳細なし）' : r.details,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  r.createdAt == null
                                      ? '作成: —'
                                      : '作成: ${r.createdAt!.toLocal()}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey.shade700),
                                ),
                                const Spacer(),
                                OutlinedButton(
                                  onPressed: (applied || applying)
                                      ? null
                                      : () => _applyToJob(r),
                                  child: Text(
                                    applied
                                        ? '応募済み'
                                        : (applying ? '応募中…' : '応募'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<JobRequestCardData> _applyFilterAndSort(List<JobRequestCardData> input) {
    final q = _queryController.text.trim().toLowerCase();

    final filtered = input.where((r) {
      if (r.status != 'open') return false;
      if (_services.isNotEmpty && !_services.contains(r.service)) return false;

      if (_durationMin != null && r.durationMinutes < _durationMin!) return false;
      if (_durationMax != null && r.durationMinutes > _durationMax!) return false;

      if (q.isNotEmpty) {
        final hay = '${r.locationText} ${r.details}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (_sort == JobSort.distance) {
        final aKm = (_lat != null && _lng != null && a.lat != null && a.lng != null)
            ? haversineKm(_lat!, _lng!, a.lat!, a.lng!)
            : double.infinity;
        final bKm = (_lat != null && _lng != null && b.lat != null && b.lng != null)
            ? haversineKm(_lat!, _lng!, b.lat!, b.lng!)
            : double.infinity;
        final byDist = aKm.compareTo(bKm);
        if (byDist != 0) return byDist;
      }
      // 新着: updatedAt/createdAt の降順
      final aTs = a.updatedAt ?? a.createdAt;
      final bTs = b.updatedAt ?? b.createdAt;
      if (aTs != null && bTs != null) return bTs.compareTo(aTs);
      if (aTs != null) return -1;
      if (bTs != null) return 1;
      return 0;
    });

    return filtered;
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final servicesAll = const <String>[
      '掃除',
      '家事代行',
      'ベビー',
      '見守り',
      'ペット',
      '買い物',
    ];

    final selected = Set<String>.from(_services);
    int? durationMin = _durationMin;
    int? durationMax = _durationMax;
    final latController = TextEditingController(text: _lat?.toString() ?? '');
    final lngController = TextEditingController(text: _lng?.toString() ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
            left: 16,
            right: 16,
            top: 8,
          ),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'フィルター',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'サービス',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: servicesAll.map((s) {
                        final on = selected.contains(s);
                        return FilterChip(
                          label: Text(s),
                          selected: on,
                          onSelected: (v) {
                            setSheet(() {
                              if (v) {
                                selected.add(s);
                              } else {
                                selected.remove(s);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '時間（分）',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            value: durationMin,
                            items: const [
                              DropdownMenuItem(value: null, child: Text('下限なし')),
                              DropdownMenuItem(value: 60, child: Text('60分〜')),
                              DropdownMenuItem(value: 120, child: Text('120分〜')),
                              DropdownMenuItem(value: 180, child: Text('180分〜')),
                            ],
                            onChanged: (v) => setSheet(() => durationMin = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            value: durationMax,
                            items: const [
                              DropdownMenuItem(value: null, child: Text('上限なし')),
                              DropdownMenuItem(value: 60, child: Text('〜60分')),
                              DropdownMenuItem(value: 120, child: Text('〜120分')),
                              DropdownMenuItem(value: 180, child: Text('〜180分')),
                            ],
                            onChanged: (v) => setSheet(() => durationMax = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '現在地（距離順用・任意）',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '緯度',
                              hintText: '例: 35.681',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: lngController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '経度',
                              hintText: '例: 139.767',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheet(() {
                                selected.clear();
                                durationMin = null;
                                durationMax = null;
                                latController.clear();
                                lngController.clear();
                              });
                            },
                            child: const Text('リセット'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final lat =
                                  double.tryParse(latController.text.trim());
                              final lng =
                                  double.tryParse(lngController.text.trim());
                              setState(() {
                                _services
                                  ..clear()
                                  ..addAll(selected);
                                _durationMin = durationMin;
                                _durationMax = durationMax;
                                _lat = lat;
                                _lng = lng;
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('適用'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class JobRequestCardData {
  JobRequestCardData({
    required this.id,
    required this.status,
    required this.service,
    required this.durationMinutes,
    required this.locationText,
    required this.details,
    this.createdAt,
    this.updatedAt,
    this.lat,
    this.lng,
  });

  final String id;
  final String status;
  final String service;
  final int durationMinutes;
  final String locationText;
  final String details;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? lat;
  final double? lng;

  static JobRequestCardData? fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    final status = d['status'];
    final service = d['service'];
    final duration = d['durationMinutes'];
    final locationTextRaw = d['locationText'];
    if (status is! String ||
        status.trim().isEmpty ||
        service is! String ||
        service.trim().isEmpty ||
        duration is! num) {
      return null;
    }

    final locationText = (locationTextRaw is String)
        ? locationTextRaw.trim()
        : '';

    final details = d['details'] is String ? d['details'] as String : '';
    final createdAt = d['createdAt'] is Timestamp
        ? (d['createdAt'] as Timestamp).toDate()
        : null;
    final updatedAt = d['updatedAt'] is Timestamp
        ? (d['updatedAt'] as Timestamp).toDate()
        : null;

    double? lat;
    double? lng;
    final geo = d['geo'];
    if (geo is GeoPoint) {
      lat = geo.latitude;
      lng = geo.longitude;
    } else {
      final latRaw = d['lat'];
      final lngRaw = d['lng'];
      if (latRaw is num) lat = latRaw.toDouble();
      if (lngRaw is num) lng = lngRaw.toDouble();
    }

    return JobRequestCardData(
      id: doc.id,
      status: status.trim(),
      service: service.trim(),
      durationMinutes: duration.toInt(),
      locationText: locationText.isEmpty ? '未設定' : locationText,
      details: details.trim(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      lat: lat,
      lng: lng,
    );
  }
}

class _ServiceQuickChips extends StatelessWidget {
  const _ServiceQuickChips({
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final void Function(String service) onToggle;

  @override
  Widget build(BuildContext context) {
    const servicesAll = <String>[
      '掃除',
      '家事代行',
      'ベビー',
      '見守り',
      'ペット',
      '買い物',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: servicesAll.map((s) {
          final on = selected.contains(s);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s),
              selected: on,
              onSelected: (_) => onToggle(s),
            ),
          );
        }).toList(),
      ),
    );
  }
}

double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(lat1)) *
          cos(_deg2rad(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return r * c;
}

double _deg2rad(double deg) => deg * (pi / 180.0);

class JobRequestDetailsPage extends StatefulWidget {
  const JobRequestDetailsPage({super.key, required this.jobId});

  final String jobId;

  @override
  State<JobRequestDetailsPage> createState() => _JobRequestDetailsPageState();
}

class _JobRequestDetailsPageState extends State<JobRequestDetailsPage> {
  bool _applying = false;

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    return dt.toLocal().toString();
  }

  Future<void> _apply() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_applying) return;
    setState(() => _applying = true);
    try {
      final jobRef = FirebaseFirestore.instance
          .collection('jobRequests')
          .doc(widget.jobId);
      final appId = '${widget.jobId}_${user.uid}';
      final appRef =
          FirebaseFirestore.instance.collection('jobApplications').doc(appId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final jobSnap = await tx.get(jobRef);
        final job = jobSnap.data();
        if (job == null) throw Exception('JOB_NOT_FOUND');
        final status = job['status'];
        if (status is String && status != 'open') throw Exception('JOB_CLOSED');

        final appSnap = await tx.get(appRef);
        if (appSnap.exists) throw Exception('ALREADY_APPLIED');

        tx.set(appRef, <String, Object?>{
          'jobRequestId': widget.jobId,
          'workerId': user.uid,
          'clientId': job['clientId'] is String ? job['clientId'] as String : null,
          'service': job['service'] is String ? job['service'] as String : null,
          'durationMinutes': job['durationMinutes'] is num
              ? (job['durationMinutes'] as num).toInt()
              : null,
          'status': 'applied',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('応募しました')));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('ALREADY_APPLIED')
          ? '応募済みです'
          : e.toString().contains('JOB_CLOSED')
              ? 'この依頼は受付終了です'
              : e.toString().contains('permission-denied')
                  ? '権限がありません（Firestoreルールを確認してください）'
                  : '応募に失敗しました';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未ログインです')));
    }

    final jobRef = FirebaseFirestore.instance
        .collection('jobRequests')
        .doc(widget.jobId);
    final appRef = FirebaseFirestore.instance
        .collection('jobApplications')
        .doc('${widget.jobId}_${user.uid}');

    return Scaffold(
      appBar: AppBar(title: const Text('依頼の詳細')),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: jobRef.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('読み込みに失敗しました'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final d = snap.data!.data();
            if (d == null) {
              return const Center(child: Text('依頼が見つかりませんでした'));
            }

            final service = d['service'] is String ? d['service'] as String : '—';
            final status = d['status'] is String ? d['status'] as String : '—';
            final duration = d['durationMinutes'] is num
                ? (d['durationMinutes'] as num).toInt()
                : null;
            final locationText =
                d['locationText'] is String ? d['locationText'] as String : '未設定';
            final details = d['details'] is String ? d['details'] as String : '';
            final createdAt = d['createdAt'] is Timestamp
                ? (d['createdAt'] as Timestamp).toDate()
                : null;
            final updatedAt = d['updatedAt'] is Timestamp
                ? (d['updatedAt'] as Timestamp).toDate()
                : null;

            String timeWindowText = '—';
            final tw = d['timeWindow'];
            if (tw is Map) {
              final m = tw.cast<String, Object?>();
              final s = m['start'];
              final e = m['end'];
              if (s is String && e is String && s.isNotEmpty && e.isNotEmpty) {
                timeWindowText = '$s 〜 $e';
              }
            }

            final appliedCoupon = d['appliedCoupon'];
            String couponText = 'なし';
            if (appliedCoupon is Map) {
              final m = appliedCoupon.cast<String, Object?>();
              final title = m['title'];
              if (title is String && title.trim().isNotEmpty) {
                couponText = title.trim();
              }
            }

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
                        Text(
                          service,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ステータス: $status',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _kv(context, '時間目安', duration == null ? '—' : '${duration}分'),
                        _kv(context, '時間帯', timeWindowText),
                        _kv(context, '場所', locationText),
                        _kv(context, 'クーポン', couponText),
                        _kv(context, '作成', _formatDateTime(createdAt)),
                        _kv(context, '更新', _formatDateTime(updatedAt)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '詳細',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(details.isEmpty ? '（詳細なし）' : details),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: appRef.snapshots(),
                  builder: (context, appSnap) {
                    final alreadyApplied = appSnap.data?.exists == true;
                    final canApply = status == 'open' && !alreadyApplied;

                    return FilledButton(
                      onPressed: (_applying || !canApply) ? null : _apply,
                      child: Text(
                        alreadyApplied
                            ? '応募済み'
                            : (_applying ? '応募中…' : '応募する'),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              k,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}


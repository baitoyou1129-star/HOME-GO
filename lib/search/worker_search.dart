import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum WorkerSort { distance, heat }

class WorkerSearchTab extends StatefulWidget {
  const WorkerSearchTab({super.key});

  @override
  State<WorkerSearchTab> createState() => _WorkerSearchTabState();
}

class _WorkerSearchTabState extends State<WorkerSearchTab> {
  final _queryController = TextEditingController();

  WorkerSort _sort = WorkerSort.heat;
  final Set<String> _services = <String>{};
  int? _priceMaxYen;
  double? _ratingMin;

  // 距離順のための簡易現在地（手入力）
  double? _lat;
  double? _lng;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // インデックス地獄を避けるため、MVPは「ある程度まとめて取ってアプリ側で絞る」
    final baseQuery = FirebaseFirestore.instance
        .collection('workers')
        .orderBy('updatedAt', descending: true)
        .limit(200);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            children: [
              TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: 'ワーカーを検索（名前・サービス）',
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<WorkerSort>(
                      value: _sort,
                      decoration: const InputDecoration(
                        labelText: '並び替え',
                        prefixIcon: Icon(Icons.sort),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: WorkerSort.distance,
                          child: Text('距離順'),
                        ),
                        DropdownMenuItem(
                          value: WorkerSort.heat,
                          child: Text('サービス内容'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _sort = v);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openFilterSheet(context),
                      icon: const Icon(Icons.tune),
                      label: const Text('フィルター'),
                    ),
                  ),
                ],
              ),
              if (_sort == WorkerSort.distance && (_lat == null || _lng == null))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '距離順は「フィルター」で現在地(緯度/経度)を入力すると有効になります。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                ),
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

              final workers = snapshot.data!.docs
                  .map((d) => WorkerCardData.fromDoc(d))
                  .where((w) => w != null)
                  .cast<WorkerCardData>()
                  .toList();

              final filtered = _applyFilterAndSort(workers);
              if (filtered.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('条件に合うワーカーが見つかりませんでした。'),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final w = filtered[idx];
                  final distanceKm = (_lat != null &&
                          _lng != null &&
                          w.lat != null &&
                          w.lng != null)
                      ? haversineKm(_lat!, _lng!, w.lat!, w.lng!)
                      : null;

                  return Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                child: Icon(Icons.person_outline),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      w.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      w.areaText ?? 'エリア未設定',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '内容 ${w.heatScore.toStringAsFixed(0)}',
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
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: w.services.take(6).map((s) {
                              return Chip(
                                label: Text(s),
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.star, size: 18, color: Colors.amber.shade700),
                              const SizedBox(width: 4),
                              Text(
                                w.rating == null ? '—' : w.rating!.toStringAsFixed(1),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const Spacer(),
                              Text(
                                w.priceYenPerHour == null
                                    ? '料金 未設定'
                                    : '¥${w.priceYenPerHour}/時間',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
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
        ),
      ],
    );
  }

  List<WorkerCardData> _applyFilterAndSort(List<WorkerCardData> input) {
    final q = _queryController.text.trim().toLowerCase();

    final filtered = input.where((w) {
      if (w.isActive == false) return false;

      if (_services.isNotEmpty && _services.intersection(w.services.toSet()).isEmpty) {
        return false;
      }
      if (_priceMaxYen != null && w.priceYenPerHour != null && w.priceYenPerHour! > _priceMaxYen!) {
        return false;
      }
      if (_ratingMin != null && (w.rating ?? 0) < _ratingMin!) return false;

      if (q.isNotEmpty) {
        final hay = '${w.displayName} ${w.services.join(" ")}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      if (_sort == WorkerSort.distance) {
        final aKm = (_lat != null && _lng != null && a.lat != null && a.lng != null)
            ? haversineKm(_lat!, _lng!, a.lat!, a.lng!)
            : double.infinity;
        final bKm = (_lat != null && _lng != null && b.lat != null && b.lng != null)
            ? haversineKm(_lat!, _lng!, b.lat!, b.lng!)
            : double.infinity;
        final byDist = aKm.compareTo(bKm);
        if (byDist != 0) return byDist;
      }
      // デフォはサービス内容（MVP: heatScoreで代用）
      return b.heatScore.compareTo(a.heatScore);
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
    int? priceMax = _priceMaxYen;
    double? ratingMin = _ratingMin;
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
                      '料金（上限）',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      value: priceMax,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('指定なし')),
                        DropdownMenuItem(value: 2000, child: Text('〜 ¥2,000/時間')),
                        DropdownMenuItem(value: 3000, child: Text('〜 ¥3,000/時間')),
                        DropdownMenuItem(value: 4000, child: Text('〜 ¥4,000/時間')),
                        DropdownMenuItem(value: 5000, child: Text('〜 ¥5,000/時間')),
                      ],
                      onChanged: (v) => setSheet(() => priceMax = v),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '評価（下限）',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<double?>(
                      value: ratingMin,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('指定なし')),
                        DropdownMenuItem(value: 3.0, child: Text('★3.0以上')),
                        DropdownMenuItem(value: 4.0, child: Text('★4.0以上')),
                        DropdownMenuItem(value: 4.5, child: Text('★4.5以上')),
                      ],
                      onChanged: (v) => setSheet(() => ratingMin = v),
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
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
                                priceMax = null;
                                ratingMin = null;
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
                              final lat = double.tryParse(latController.text.trim());
                              final lng = double.tryParse(lngController.text.trim());
                              setState(() {
                                _services
                                  ..clear()
                                  ..addAll(selected);
                                _priceMaxYen = priceMax;
                                _ratingMin = ratingMin;
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

class WorkerCardData {
  WorkerCardData({
    required this.id,
    required this.displayName,
    required this.services,
    required this.heatScore,
    required this.isActive,
    this.areaText,
    this.priceYenPerHour,
    this.rating,
    this.lat,
    this.lng,
  });

  final String id;
  final String displayName;
  final List<String> services;
  final double heatScore;
  final bool isActive;
  final String? areaText;
  final int? priceYenPerHour;
  final double? rating;
  final double? lat;
  final double? lng;

  static WorkerCardData? fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final displayName = d['displayName'];
    if (displayName is! String || displayName.trim().isEmpty) return null;

    final services = (d['services'] as List?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    final heat = d['heatScore'];
    final heatScore = heat is num ? heat.toDouble() : 0.0;

    final isActive = d['isActive'];
    final active = isActive is bool ? isActive : true;

    final areaText = d['areaText'] is String ? d['areaText'] as String : null;
    final price = d['priceYenPerHour'];
    final priceYenPerHour = price is num ? price.toInt() : null;
    final rating = d['rating'];
    final ratingVal = rating is num ? rating.toDouble() : null;

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

    return WorkerCardData(
      id: doc.id,
      displayName: displayName.trim(),
      services: services,
      heatScore: heatScore,
      isActive: active,
      areaText: areaText,
      priceYenPerHour: priceYenPerHour,
      rating: ratingVal,
      lat: lat,
      lng: lng,
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


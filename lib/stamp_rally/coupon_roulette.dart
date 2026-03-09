import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RoulettePrize {
  const RoulettePrize({
    required this.id,
    required this.title,
    required this.description,
    required this.weight,
    required this.color,
    this.percentOff,
    this.yenOff,
  });

  final String id;
  final String title;
  final String description;
  final double weight;
  final Color color;
  final int? percentOff;
  final int? yenOff;
}

class CouponRouletteCard extends StatefulWidget {
  const CouponRouletteCard({
    super.key,
    this.totalTurns = 6,
  });

  final int totalTurns;

  @override
  State<CouponRouletteCard> createState() => _CouponRouletteCardState();
}

class _CouponRouletteCardState extends State<CouponRouletteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _rotationAnim;
  double _rotationBase = 0.0; // radians（最後に止まった角度）
  bool _spinning = false;
  RoulettePrize? _lastPrize;

  static const _prizes = <RoulettePrize>[
    RoulettePrize(
      id: 'p5',
      title: '5%OFF',
      description: '次回のお会計が5%OFF',
      percentOff: 5,
      weight: 40,
      color: Color(0xFF4DA3FF),
    ),
    RoulettePrize(
      id: 'p10',
      title: '10%OFF',
      description: '次回のお会計が10%OFF',
      percentOff: 10,
      weight: 22,
      color: Color(0xFF2ED6B3),
    ),
    RoulettePrize(
      id: 'y300',
      title: '¥300 OFF',
      description: '次回¥300割引',
      yenOff: 300,
      weight: 18,
      color: Color(0xFFFF8A00),
    ),
    RoulettePrize(
      id: 'y500',
      title: '¥500 OFF',
      description: '次回¥500割引',
      yenOff: 500,
      weight: 12,
      color: Color(0xFF8B5CF6),
    ),
    RoulettePrize(
      id: 'p15',
      title: '15%OFF',
      description: '次回のお会計が15%OFF',
      percentOff: 15,
      weight: 8,
      color: Color(0xFFEF4444),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  RoulettePrize _pickPrize(Random rng) {
    final total = _prizes.fold<double>(0, (sum, p) => sum + p.weight);
    var r = rng.nextDouble() * total;
    for (final p in _prizes) {
      r -= p.weight;
      if (r <= 0) return p;
    }
    return _prizes.last;
  }

  double _segmentCenterAngle(RoulettePrize target) {
    final total = _prizes.fold<double>(0, (sum, p) => sum + p.weight);
    const start = -pi / 2; // top
    var acc = 0.0;
    for (final p in _prizes) {
      final sweep = (p.weight / total) * 2 * pi;
      final segStart = start + acc;
      if (p.id == target.id) {
        return segStart + sweep / 2;
      }
      acc += sweep;
    }
    return start;
  }

  Future<void> _spin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }
    if (_spinning) return;
    setState(() => _spinning = true);

    final rng = Random();
    final prize = _pickPrize(rng);
    final center = _segmentCenterAngle(prize);
    const pointer = -pi / 2;
    final baseTarget = pointer - center; // ポインタが当選セグメント中心を指す角度

    // たくさん回して止める
    final target = _rotationBase +
        (2 * pi * widget.totalTurns) +
        _normalizeTo2Pi(baseTarget - _rotationBase);

    _rotationAnim = Tween<double>(
      begin: _rotationBase,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    await _controller.forward(from: 0);
    _rotationBase = target % (2 * pi);

    setState(() {
      _lastPrize = prize;
      _spinning = false;
    });

    await _savePrize(userId: user.uid, prize: prize);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('当たり！'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prize.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(prize.description),
              const SizedBox(height: 10),
              Text(
                'クーポンに追加しました。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _savePrize({
    required String userId,
    required RoulettePrize prize,
  }) async {
    final now = DateTime.now();
    final expiresAt = Timestamp.fromDate(now.add(const Duration(days: 30)));
    final code = _randomCode();

    await FirebaseFirestore.instance.collection('userCoupons').add(
      <String, Object?>{
        'userId': userId,
        // スタンプラリーの「プレゼント（クーポン）」として発行
        'source': 'stampRallyRoulette',
        'rewardType': 'coupon',
        'prizeId': prize.id,
        'title': prize.title,
        'description': prize.description,
        'couponCode': code,
        'percentOff': prize.percentOff,
        'yenOff': prize.yenOff,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt,
        'usedAt': null,
      },
    );
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  double _normalizeTo2Pi(double x) {
    var v = x % (2 * pi);
    if (v < 0) v += 2 * pi;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final prize = _lastPrize;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.casino_outlined, color: cs.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'プレゼント（クーポン）ルーレット',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'ルーレットで「クーポン内容」を決めてGETできます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final angle = _rotationAnim?.value ?? _rotationBase;
                        final glow = _spinning ? 0.14 + 0.10 * sin(_controller.value * pi) : 0.12;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: glow),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Transform.rotate(
                            angle: angle,
                            child: CustomPaint(
                              painter: _RoulettePainter(_prizes),
                            ),
                          ),
                        );
                      },
                    ),
                    // ポインタ（回転中は少しピコピコ動かす）
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final wiggle = _spinning ? sin(_controller.value * 14 * pi) * 2.2 : 0.0;
                        return Positioned(
                          top: 2 + wiggle,
                          child: Icon(
                            Icons.arrow_drop_down,
                            size: 46,
                            color: cs.onSurface.withValues(alpha: 0.88),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Center(
                        child: Text(
                          _spinning ? '…' : 'SPIN',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                        ),
                      ),
                    ),
                    // タップ領域
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _spinning ? null : _spin,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _spinning ? null : _spin,
              icon: const Icon(Icons.play_arrow),
              label: Text(_spinning ? '回転中…' : '回す'),
            ),
            if (prize != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: prize.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: cs.tertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '前回の当選: ${prize.title}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoulettePainter extends CustomPainter {
  _RoulettePainter(this.prizes);

  final List<RoulettePrize> prizes;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = prizes.fold<double>(0, (sum, p) => sum + p.weight);
    var start = -pi / 2;

    final paint = Paint()..style = PaintingStyle.fill;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.9);

    final textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w900,
      shadows: [
        Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2)),
      ],
    );

    for (final p in prizes) {
      final sweep = (p.weight / total) * 2 * pi;
      paint.color = p.color.withValues(alpha: 0.95);
      canvas.drawArc(rect, start, sweep, true, paint);
      canvas.drawArc(rect, start, sweep, true, border);

      // ラベル（セグメントの中央に回転させて描画）
      final mid = start + sweep / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(mid);
      final tp = TextPainter(
        text: TextSpan(text: p.title, style: textStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius);
      // 上向き（外側）に配置
      tp.paint(canvas, Offset(-tp.width / 2, -radius * 0.62 - tp.height / 2));
      canvas.restore();

      start += sweep;
    }

    // 中央を少しクリアに
    canvas.drawCircle(
      center,
      radius * 0.10,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // 外枠
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(covariant _RoulettePainter oldDelegate) => false;
}


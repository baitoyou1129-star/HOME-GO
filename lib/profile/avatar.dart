import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.userRef,
    this.radius = 24,
  });

  final DocumentReference<Map<String, dynamic>> userRef;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final avatar = (data?['avatar'] is Map)
            ? (data!['avatar'] as Map).cast<String, Object?>()
            : const <String, Object?>{};

        final kind = avatar['kind'];
        if (kind == 'photo') {
          final url = avatar['url'];
          if (url is String && url.trim().isNotEmpty) {
            return ClipOval(
              child: Container(
                width: radius * 2,
                height: radius * 2,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.person_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: radius,
                        height: radius,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: progress.expectedTotalBytes == null
                              ? null
                              : progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          }
        }
        if (kind == 'materialIcon') {
          final cp = avatar['codePoint'];
          final col = avatar['color'];
          if (cp is int) {
            final color = (col is int) ? Color(col) : null;
            return CircleAvatar(
              radius: radius,
              backgroundColor:
                  (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.15),
              child: Icon(
                IconData(cp, fontFamily: 'MaterialIcons'),
                color: color ?? Theme.of(context).colorScheme.primary,
              ),
            );
          }
        }

        // default
        return CircleAvatar(
          radius: radius,
          child: const Icon(Icons.person_outline),
        );
      },
    );
  }
}


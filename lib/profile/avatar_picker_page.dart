import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AvatarPickerPage extends StatefulWidget {
  const AvatarPickerPage({super.key});

  static const _icons = <IconData>[
    Icons.person,
    Icons.face,
    Icons.sentiment_satisfied_alt,
    Icons.home,
    Icons.cleaning_services,
    Icons.local_florist,
    Icons.pets,
    Icons.favorite,
    Icons.star,
    Icons.handyman,
    Icons.shopping_bag,
    Icons.child_friendly,
  ];

  @override
  State<AvatarPickerPage> createState() => _AvatarPickerPageState();
}

class _AvatarPickerPageState extends State<AvatarPickerPage> {
  bool _uploading = false;
  double? _progress;

  Future<void> _pickAndUpload({
    required DocumentReference<Map<String, dynamic>> userRef,
    required String userId,
    required ImageSource source,
  }) async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _progress = null;
    });

    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (x == null) return;

      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child(userId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      UploadTask task;
      if (kIsWeb) {
        final bytes = await x.readAsBytes();
        task = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        task = ref.putFile(
          File(x.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      task.snapshotEvents.listen((s) {
        final total = s.totalBytes;
        final sent = s.bytesTransferred;
        setState(() {
          _progress = total == 0 ? null : sent / total;
        });
      });

      await task;
      final url = await ref.getDownloadURL();

      await userRef.set(
        <String, Object?>{
          'avatar': <String, Object?>{
            'kind': 'photo',
            'url': url,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像をアイコンに設定しました')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像の設定に失敗しました')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未ログインです')));
    }

    final cs = Theme.of(context).colorScheme;
    final colors = <Color>[
      cs.primary,
      cs.secondary,
      cs.tertiary,
      const Color(0xFF6B7280), // gray
      const Color(0xFF10B981), // green
      const Color(0xFF8B5CF6), // purple
      const Color(0xFFEF4444), // red
    ];

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('アイコンを選ぶ')),
      body: SafeArea(
        child: ListView(
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
                      '好きなアイコンを選んでください',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _uploading
                          ? null
                          : () => _pickAndUpload(
                                userRef: userRef,
                                userId: user.uid,
                                source: ImageSource.gallery,
                              ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('自分の画像をアイコンにする（ギャラリー）'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _uploading
                          ? null
                          : () => _pickAndUpload(
                                userRef: userRef,
                                userId: user.uid,
                                source: ImageSource.camera,
                              ),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('カメラで撮ってアイコンにする'),
                    ),
                    if (_uploading) ...[
                      const SizedBox(height: 10),
                      LinearProgressIndicator(value: _progress),
                    ],
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: AvatarPickerPage._icons.length * colors.length,
                      itemBuilder: (context, i) {
                        final icon = AvatarPickerPage._icons[i % AvatarPickerPage._icons.length];
                        final color = colors[
                            (i ~/ AvatarPickerPage._icons.length) % colors.length];
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            await userRef.set(
                              <String, Object?>{
                                'avatar': <String, Object?>{
                                  'kind': 'materialIcon',
                                  'codePoint': icon.codePoint,
                                  'color': color.value,
                                },
                                'updatedAt': FieldValue.serverTimestamp(),
                              },
                              SetOptions(merge: true),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('アイコンを変更しました')),
                            );
                            Navigator.of(context).pop();
                          },
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outlineVariant,
                              ),
                            ),
                            child: Center(
                              child: Icon(icon, color: color, size: 28),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await userRef.set(
                          <String, Object?>{
                            'avatar': FieldValue.delete(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          },
                          SetOptions(merge: true),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('アイコンをリセットしました')),
                        );
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('リセット'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


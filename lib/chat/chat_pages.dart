import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatThreadsPage extends StatelessWidget {
  const ChatThreadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未ログインです')));
    }

    final threadsQuery = FirebaseFirestore.instance
        .collection('threads')
        .where('participants', arrayContains: user.uid)
        .orderBy('updatedAt', descending: true)
        .limit(50);

    return Scaffold(
      appBar: AppBar(title: const Text('チャット')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: threadsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('読み込みに失敗しました'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('スレッドがありません。'),
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final d = docs[idx];
              final data = d.data();
              final participants =
                  (data['participants'] as List?)
                      ?.whereType<String>()
                      .toList() ??
                  const <String>[];
              final otherUid = participants.firstWhere(
                (p) => p != user.uid,
                orElse: () => '',
              );
              final last = (data['lastMessageText'] is String)
                  ? data['lastMessageText'] as String
                  : '';

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(otherUid.isEmpty ? 'スレッド' : otherUid),
                subtitle: Text(
                  last.isEmpty ? '（メッセージなし）' : last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatThreadPage(threadId: d.id, otherUid: otherUid),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.threadId,
    required this.otherUid,
  });

  final String threadId;
  final String otherUid;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      _controller.clear();

      final threadRef = FirebaseFirestore.instance
          .collection('threads')
          .doc(widget.threadId);
      final msgRef = threadRef.collection('messages').doc();

      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(msgRef, <String, Object?>{
          'senderId': user.uid,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(threadRef, <String, Object?>{
          'participants': <String>[user.uid, widget.otherUid],
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessageText': text,
          'lastMessageAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未ログインです')));
    }

    final messagesQuery = FirebaseFirestore.instance
        .collection('threads')
        .doc(widget.threadId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUid.isEmpty ? 'チャット' : widget.otherUid),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messagesQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('読み込みに失敗しました'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('最初のメッセージを送ってみよう'));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: docs.length,
                  itemBuilder: (context, idx) {
                    final data = docs[idx].data();
                    final senderId = data['senderId'] is String
                        ? data['senderId'] as String
                        : '';
                    final text = data['text'] is String
                        ? data['text'] as String
                        : '';
                    final mine = senderId == user.uid;
                    final cs = Theme.of(context).colorScheme;

                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: mine ? cs.primary : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: mine
                              ? null
                              : Border.all(color: cs.outlineVariant),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: mine ? Colors.white : cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sending ? null : _send(),
                      decoration: const InputDecoration(
                        hintText: 'メッセージを入力',
                        prefixIcon: Icon(Icons.chat_bubble_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    child: Text(_sending ? '送信中…' : '送信'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

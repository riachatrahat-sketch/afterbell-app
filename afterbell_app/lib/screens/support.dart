import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'notices.dart';

/// Chat with the Afterbell team. Messages are answered from the WordPress admin.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController input = TextEditingController();
  final ScrollController scroll = ScrollController();
  List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
  bool loading = true, sending = false;
  String? error;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 15), (_) => load(quiet: true));
  }

  @override
  void dispose() {
    timer?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> load({bool quiet = false}) async {
    try {
      final Map<String, dynamic> d = await AppScope.read(context).api.get('/support');
      if (!mounted) return;
      final List<Map<String, dynamic>> next = rows(d['items']);
      final bool grew = next.length != items.length;
      setState(() {
        items = next;
        loading = false;
        error = null;
      });
      if (grew) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.signedOut) AppScope.read(context).sessionEnded();
      if (!quiet) {
        setState(() {
          loading = false;
          error = e.message;
        });
      }
    }
  }

  Future<void> send() async {
    final String t = input.text.trim();
    if (t.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await AppScope.read(context).api.post('/support', <String, dynamic>{'text': t});
      input.clear();
      await load(quiet: true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => sending = false);
  }

  Widget bubble(Map<String, dynamic> m) {
    final bool mine = str(m['from']) == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFFFE6A8) : Colors.white,
          border: Border.all(color: AB.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!mine) Text(str(m['name'], 'Afterbell team'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AB.teal)),
            Text(str(m['text']), style: const TextStyle(color: AB.dusk, height: 1.35)),
            const SizedBox(height: 4),
            Text(timeAgo(num0(m['time'])), style: const TextStyle(fontSize: 11, color: AB.muted)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(error!, textAlign: TextAlign.center, style: mutedText)))
                    : items.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Ask us anything about classes, your account or payments. The Afterbell team will reply here.', textAlign: TextAlign.center, style: mutedText)))
                        : ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), children: <Widget>[for (final Map<String, dynamic> m in items) bubble(m)]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Write a message', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : send,
                    style: IconButton.styleFrom(backgroundColor: AB.orange, foregroundColor: AB.dusk, minimumSize: const Size(50, 50)),
                    icon: sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
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

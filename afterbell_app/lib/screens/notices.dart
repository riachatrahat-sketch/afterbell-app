import 'package:flutter/material.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// "5 min ago", "2 days ago" from a Unix time in seconds.
String timeAgo(int seconds) {
  if (seconds <= 0) return '';
  final Duration d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(seconds * 1000));
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 30) return '${d.inDays} d ago';
  return '${(d.inDays / 30).floor()} mo ago';
}

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  final GlobalKey<LoaderState> loader = GlobalKey<LoaderState>();

  Future<void> compose() async {
    final TextEditingController title = TextEditingController();
    final TextEditingController text = TextEditingController();
    final bool? send = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: const Text('Post a notice'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Your students and families will see this.', style: mutedText),
              const SizedBox(height: 12),
              TextField(controller: title, maxLength: 120, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 4),
              TextField(controller: text, maxLines: 4, maxLength: 1500, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Message')),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Post')),
        ],
      ),
    );
    final String t = title.text.trim();
    final String m = text.text.trim();
    title.dispose();
    text.dispose();
    if (send != true || !mounted) return;
    try {
      await AppScope.read(context).api.post('/notices', <String, dynamic>{'title': t, 'text': m, 'audience': 'students'});
      if (mounted) toast(context, 'Notice posted.');
      loader.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notices')),
      floatingActionButton: app.isTeacher ? FloatingActionButton.extended(onPressed: compose, icon: const Icon(Icons.edit_outlined), label: const Text('Post a notice')) : null,
      body: Loader(
        key: loader,
        load: () => app.api.get('/notices'),
        builder: (BuildContext context, Map<String, dynamic> d, Future<void> Function() reload) {
          final List<Map<String, dynamic>> items = rows(d['items']);
          if (items.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No notices yet. Class updates and announcements will show up here.', textAlign: TextAlign.center, style: mutedText)));
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              children: <Widget>[
                for (final Map<String, dynamic> n in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                      color: yes(n['is_new']) ? const Color(0xFFFFF6E0) : Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(child: Text(str(n['title']), style: h2)),
                              if (yes(n['is_new'])) const Pill('New', color: AB.orange, textColor: Colors.white),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(str(n['text']), style: const TextStyle(color: AB.dusk, height: 1.4)),
                          const SizedBox(height: 8),
                          Text('${str(n['by'])} · ${timeAgo(num0(n['time']))}', style: mutedText),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

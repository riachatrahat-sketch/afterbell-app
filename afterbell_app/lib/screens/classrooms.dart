import 'package:flutter/material.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'classroom.dart';

class ClassroomsScreen extends StatelessWidget {
  const ClassroomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    if (!app.signedIn) {
      return const SignInPrompt(message: 'Log in to enter a live classroom, send reactions, answer quiz questions and collect stars.');
    }
    return Loader(
      key: ValueKey<int>(num0(app.user?['id'])),
      load: () => app.api.get('/classrooms'),
      builder: (BuildContext context, Map<String, dynamic> d, Future<void> Function() reload) {
        final List<Map<String, dynamic>> items = rows(d['items']);
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              const Text('Live classroom', style: h1),
              const SizedBox(height: 6),
              const Text('Open the classroom a few minutes before the session starts.', style: mutedText),
              const SizedBox(height: 16),
              if (items.isEmpty) const Panel(child: Text('No classrooms are open to you yet. After you book a class it shows up here.', style: mutedText)),
              for (final Map<String, dynamic> c in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AB.line)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(str(c['title']), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(<String>[str(c['schedule']), str(c['teacher_name'])].where((String s) => s.isNotEmpty).join(' · ')),
                      trailing: yes(c['teach']) ? const Pill('Teach', color: AB.orange) : const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ClassroomScreen(classId: num0(c['id'])))),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

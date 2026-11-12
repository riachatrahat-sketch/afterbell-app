import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'classroom.dart';

Future<void> openLink(BuildContext context, String url) async {
  final Uri? uri = Uri.tryParse(url);
  bool ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok && context.mounted) toast(context, 'We could not open that link on this phone.');
}

class ClassDetailScreen extends StatelessWidget {
  const ClassDetailScreen({super.key, required this.id, this.title = ''});
  final int id;
  final String title;

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Class'), actions: <Widget>[FavButton(id: id)]),
      body: Loader(
        // Reload when the person signs in or out, so the classroom button is right.
        key: ValueKey<String>('class-$id-${app.signedIn}'),
        load: () => app.api.get('/class', <String, String>{'id': '$id'}),
        builder: (BuildContext context, Map<String, dynamic> c, Future<void> Function() reload) {
          final bool one = yes(c['one_to_one']);
          final Map<String, dynamic>? teacher = asMap(c['teacher']);
          final List<String> outcomes = strings(c['outcomes']);
          final String enroll = str(c['enroll_url']);
          final String contact = str(c['contact']);
          final List<List<String>> facts = <List<String>>[
            <String>['Ages', str(c['age'])],
            <String>['Grade', str(c['grade'])],
            <String>['Schedule', str(c['schedule'])],
            <String>['Each session', str(c['duration'])],
            if (num0(c['weeks']) > 0) <String>['Length', '${num0(c['weeks'])} weeks'],
            <String>['Class size', one ? 'One learner' : (num0(c['seats']) > 0 ? 'Up to ${num0(c['seats'])} learners' : '')],
            <String>['Prerequisites', str(c['prerequisites'])],
            <String>['Learning needs', str(c['needs_support'])],
            <String>['Supplies', str(c['supplies'])],
          ].where((List<String> f) => f[1].isNotEmpty).toList();

          return Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: <Widget>[
                    Align(alignment: Alignment.centerLeft, child: Pill(one ? '1:1 tutoring' : 'Live group class', color: one ? AB.sky : AB.dusk, textColor: Colors.white)),
                    const SizedBox(height: 10),
                    Text(str(c['title'], title), style: h1),
                    if (str(c['excerpt']).isNotEmpty) ...<Widget>[const SizedBox(height: 8), Text(str(c['excerpt']), style: mutedText.copyWith(fontSize: 15))],
                    const SizedBox(height: 16),
                    Panel(
                      child: Column(
                        children: <Widget>[
                          for (final List<String> f in facts)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  SizedBox(width: 120, child: Text(f[0], style: mutedText)),
                                  Expanded(child: Text(f[1], style: const TextStyle(fontWeight: FontWeight.w700, color: AB.dusk))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (teacher != null || str(c['teacher_name']).isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AB.line)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: AB.dusk,
                            foregroundColor: Colors.white,
                            backgroundImage: str(teacher?['photo']).isNotEmpty ? NetworkImage(str(teacher?['photo'])) : null,
                            child: str(teacher?['photo']).isEmpty ? Text(str(c['teacher_name'], '?').substring(0, 1).toUpperCase()) : null,
                          ),
                          title: Text(str(c['teacher_name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(str(teacher?['credential'], str(teacher?['headline'], 'Teacher'))),
                          trailing: teacher != null ? const Icon(Icons.chevron_right) : null,
                          onTap: teacher == null ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TeacherScreen(id: num0(teacher['id'])))),
                        ),
                      ),
                    ],
                    if (outcomes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 20),
                      const Text('What learners will do', style: h2),
                      const SizedBox(height: 8),
                      for (final String o in outcomes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check_circle, size: 18, color: AB.teal)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(o, style: const TextStyle(fontSize: 15, height: 1.4))),
                            ],
                          ),
                        ),
                    ],
                    if (str(c['about']).isNotEmpty) ...<Widget>[
                      const SizedBox(height: 20),
                      const Text('About this class', style: h2),
                      const SizedBox(height: 8),
                      Text(str(c['about']), style: const TextStyle(fontSize: 15, height: 1.5)),
                    ],
                  ],
                ),
              ),
              Container(
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AB.line))),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: <InlineSpan>[
                                  TextSpan(text: str(c['price']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AB.dusk)),
                                  TextSpan(text: '\n${str(c['price_unit'])}', style: const TextStyle(fontSize: 12, color: AB.muted)),
                                ],
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: () {
                              if (enroll.isNotEmpty) {
                                openLink(context, enroll);
                              } else if (contact.isNotEmpty) {
                                openLink(context, 'mailto:$contact?subject=${Uri.encodeComponent('Enquiry: ${str(c['title'])}')}');
                              } else {
                                openLink(context, str(c['web_url']));
                              }
                            },
                            child: Text(one ? 'Book a trial' : 'See times'),
                          ),
                        ],
                      ),
                      if (yes(c['can_join'])) ...<Widget>[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.videocam_outlined),
                            label: Text(yes(c['is_host']) ? 'Teach in the live classroom' : 'Enter the live classroom'),
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ClassroomScreen(classId: id))),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TeacherScreen extends StatelessWidget {
  const TeacherScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher')),
      body: Loader(
        load: () => app.api.get('/teacher', <String, String>{'id': '$id'}),
        builder: (BuildContext context, Map<String, dynamic> t, Future<void> Function() reload) {
          final List<Map<String, dynamic>> classes = rows(t['classes']);
          final String photo = str(t['photo']);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AB.dusk,
                    foregroundColor: Colors.white,
                    backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo.isEmpty ? Text(str(t['name'], '?').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(str(t['name']), style: h1),
                        if (str(t['headline']).isNotEmpty) Text(str(t['headline']), style: mutedText),
                      ],
                    ),
                  ),
                ],
              ),
              if (str(t['credential']).isNotEmpty) ...<Widget>[const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: Pill(str(t['credential']), color: AB.tones[3]))],
              if (str(t['bio']).isNotEmpty) ...<Widget>[const SizedBox(height: 16), Text(str(t['bio']), style: const TextStyle(fontSize: 15, height: 1.5))],
              if (classes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                Text('Classes with ${str(t['name'])}', style: h2),
                const SizedBox(height: 10),
                for (final Map<String, dynamic> c in classes) Padding(padding: const EdgeInsets.only(bottom: 12), child: ClassCard(c)),
              ],
            ],
          );
        },
      ),
    );
  }
}

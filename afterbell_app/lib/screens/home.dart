import 'package:flutter/material.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    return Loader(
      load: () => app.api.get('/home'),
      builder: (BuildContext context, Map<String, dynamic> d, Future<void> Function() reload) {
        final List<Map<String, dynamic>> tracks = rows(d['tracks']);
        final List<Map<String, dynamic>> subjects = rows(d['subjects']);
        final List<Map<String, dynamic>> featured = rows(d['featured']);
        final List<Map<String, dynamic>> tutors = rows(d['tutors']);
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.notifications_active, color: AB.sun),
                  SizedBox(width: 8),
                  Text('Afterbell ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AB.dusk)),
                  Text('Academy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AB.teal)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFF1B2A6B), AB.dusk]),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(str(d['headline'], 'Smart kid today. Next leader tomorrow.'), style: const TextStyle(fontSize: 26, height: 1.12, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 10),
                    Text(str(d['text']), style: const TextStyle(color: Color(0xFFC9D1EE), fontSize: 14, height: 1.45)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        FilledButton(onPressed: () => app.explore(<String, String>{'track': 'homeschool-academics'}), child: const Text('Explore homeschool')),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 1.5)),
                          onPressed: () => app.explore(<String, String>{'format': 'one_to_one'}),
                          child: const Text('Find a 1:1 tutor'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (tracks.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                const Text('Choose a path', style: h2),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final Map<String, dynamic> t in tracks)
                      ActionChip(label: Text(str(t['name'])), onPressed: () => app.explore(<String, String>{'track': str(t['slug'])})),
                  ],
                ),
              ],
              if (featured.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                _RowHead(title: 'New classes', onAll: () => app.explore(<String, String>{})),
                _Rail(items: featured),
              ],
              if (subjects.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                const Text('Subjects', style: h2),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.6,
                  children: <Widget>[
                    for (int i = 0; i < subjects.length; i++)
                      Material(
                        color: AB.tones[i % AB.tones.length],
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => app.explore(<String, String>{'subj': str(subjects[i]['slug'])}),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: <Widget>[
                                Icon(subjectIcon(str(subjects[i]['slug'])), color: AB.dusk),
                                const SizedBox(width: 8),
                                Expanded(child: Text(str(subjects[i]['name']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: AB.dusk, height: 1.15))),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (tutors.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                _RowHead(title: '1:1 tutors', onAll: () => app.explore(<String, String>{'format': 'one_to_one'})),
                _Rail(items: tutors),
              ],
              const SizedBox(height: 24),
              const Text('Classes by age', style: h2),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (int age = 3; age <= 18; age++)
                    ActionChip(label: Text('$age'), onPressed: () => app.explore(<String, String>{'age': '$age'})),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RowHead extends StatelessWidget {
  const _RowHead({required this.title, required this.onAll});
  final String title;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(title, style: h2)),
        TextButton(onPressed: onAll, child: const Text('See all')),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 262,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int i) => ClassCard(items[i], width: 250),
      ),
    );
  }
}

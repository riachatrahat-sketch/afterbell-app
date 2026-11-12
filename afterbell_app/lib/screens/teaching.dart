import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class TeachingScreen extends StatefulWidget {
  const TeachingScreen({super.key});

  @override
  State<TeachingScreen> createState() => _TeachingScreenState();
}

class _TeachingScreenState extends State<TeachingScreen> {
  int days = 30;

  Widget stat(String value, String label) {
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AB.dusk)),
          Text(label, style: mutedText),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My teaching')),
      body: Loader(
        key: ValueKey<int>(days),
        load: () => app.api.get('/teaching', <String, String>{'days': '$days'}),
        builder: (BuildContext context, Map<String, dynamic> d, Future<void> Function() reload) {
          final Map<String, dynamic> live = asMap(d['live']) ?? <String, dynamic>{};
          final List<Map<String, dynamic>> daily = rows(d['daily']);
          final List<Map<String, dynamic>> reactions = rows(d['reactions']);
          final List<Map<String, dynamic>> comments = rows(d['comments']);
          final List<Map<String, dynamic>> classes = rows(d['classes']);
          final int peak = daily.fold<int>(1, (int m, Map<String, dynamic> r) => math.max(m, num0(r['count'])));
          final int liked = num0(live['liked']);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: <Widget>[
                Text(str(d['name']), style: h1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    for (final int n in const <int>[7, 30, 90]) ChoiceChip(label: Text('$n days'), selected: days == n, onSelected: (_) => setState(() => days = n)),
                  ],
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.9,
                  children: <Widget>[
                    stat('${num0(live['sessions'])}', 'Sessions held'),
                    stat('${num0(live['joins'])}', 'Attendances'),
                    stat('${num0(live['mins'])} min', 'Average time in class'),
                    stat(liked < 0 ? '–' : '$liked%', 'Liked the class'),
                    stat('${num0(live['stars'])}', 'Stars given'),
                    stat('${num0(live['polls'])}', 'Quiz questions asked'),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Attendance by day', style: h2),
                const SizedBox(height: 10),
                Panel(
                  child: SizedBox(
                    height: 110,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        for (final Map<String, dynamic> r in daily)
                          Expanded(
                            child: Tooltip(
                              message: '${str(r['day'])}: ${num0(r['count'])}',
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                height: math.max(3.0, 110.0 * num0(r['count']) / peak),
                                decoration: BoxDecoration(color: num0(r['count']) > 0 ? AB.orange : AB.line, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('How learners felt (anonymous)', style: h2),
                const SizedBox(height: 10),
                if (reactions.isEmpty)
                  const Text('No reactions yet. They appear after learners leave feedback at the end of a class.', style: mutedText)
                else
                  Wrap(spacing: 8, runSpacing: 8, children: <Widget>[for (final Map<String, dynamic> r in reactions) Pill('${str(r['icon'])} ${str(r['label'])}  ${num0(r['count'])}')]),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('👍 ${num0(live['up'])}    👎 ${num0(live['down'])}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                if (classes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  const Text('Most attended classes', style: h2),
                  const SizedBox(height: 10),
                  Panel(
                    child: Column(
                      children: <Widget>[
                        for (final Map<String, dynamic> c in classes)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(children: <Widget>[Expanded(child: Text(str(c['title']))), Text('${num0(c['joins'])}', style: const TextStyle(fontWeight: FontWeight.w800))]),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text('Anonymous comments', style: h2),
                const SizedBox(height: 10),
                if (comments.isEmpty) const Text('No comments yet.', style: mutedText),
                for (final Map<String, dynamic> c in comments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('${num0(c['vote']) > 0 ? '👍 ' : (num0(c['vote']) < 0 ? '👎 ' : '')}${str(c['icon'])} ${str(c['class'])} · ${str(c['day'])}', style: mutedText),
                          const SizedBox(height: 6),
                          Text(str(c['comment']), style: const TextStyle(fontSize: 15, height: 1.4)),
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

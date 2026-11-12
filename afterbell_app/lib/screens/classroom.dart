import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'class_detail.dart' show openLink;

const List<String> _breakTips = <String>[
  'Stand up and stretch to the sky.',
  'Take five slow, deep breaths.',
  'Get a sip of water.',
  'Shake out your hands and wiggle your fingers.',
  'Look out of a window at something far away.',
  'Do ten jumping jacks.',
];

class ClassroomScreen extends StatefulWidget {
  const ClassroomScreen({super.key, required this.classId});
  final int classId;

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  late final Api api;
  Map<String, dynamic>? info; // title, names, moods, reactions, feedback, is_host
  Map<String, dynamic>? room; // latest state from the server
  String? loadError;
  String name = '';
  String mood = '';
  String videoUrl = '';
  bool joined = false, joining = false, wasLive = false, asked = false, sending = false;
  int since = 0, lastPollId = 0, tabIndex = 0, flyKey = 0;
  DateTime lastReact = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? breakEnds;
  String breakTip = '';
  Timer? pollTimer, tick;
  final List<_Fly> flying = <_Fly>[];
  final math.Random random = math.Random();
  bool started = false;

  bool get host => yes(info?['is_host']);
  Map<String, String> get reactionIcons => <String, String>{for (final Map<String, dynamic> r in rows(info?['reactions'])) str(r['key']): str(r['icon'])};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      api = AppScope.read(context).api;
      loadInfo();
    }
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    tick?.cancel();
    super.dispose();
  }

  Future<void> loadInfo() async {
    setState(() => loadError = null);
    try {
      final Map<String, dynamic> d = await api.get('/classroom', <String, String>{'id': '${widget.classId}'});
      if (!mounted) return;
      final List<String> names = strings(d['names']);
      setState(() {
        info = d;
        name = names.isNotEmpty ? names.first : '';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => loadError = e.message);
    }
  }

  Future<Map<String, dynamic>> rpc(String action, [Map<String, dynamic> extra = const <String, dynamic>{}]) {
    return api.post('/live', <String, dynamic>{'do': action, 'class': widget.classId, 'name': name, 'since': since, ...extra});
  }

  Future<void> join() async {
    setState(() => joining = true);
    try {
      final Map<String, dynamic> s = await rpc('join', <String, dynamic>{'mood': mood});
      if (!mounted) return;
      final Map<String, dynamic>? v = asMap(s['video']);
      if (v != null) {
        if (str(v['mode']) == 'embed') {
          final String jwt = str(v['jwt']);
          videoUrl = 'https://${str(v['domain'])}/${str(v['room'])}${jwt.isEmpty ? '' : '?jwt=$jwt'}';
        } else {
          videoUrl = str(v['url']);
        }
      }
      setState(() {
        joined = true;
        joining = false;
        tabIndex = host ? 2 : 0;
      });
      apply(s);
      schedulePoll();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => joining = false);
      toast(context, e.message);
    }
  }

  void schedulePoll() {
    pollTimer?.cancel();
    pollTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted || !joined) return;
      try {
        apply(await rpc('poll'));
      } on ApiException catch (e) {
        if (!mounted) return;
        if (e.signedOut) {
          AppScope.read(context).sessionEnded();
          Navigator.of(context).maybePop();
          return;
        }
      }
      if (mounted && joined) schedulePoll();
    });
  }

  Future<void> act(String type, [Map<String, dynamic> extra = const <String, dynamic>{}]) async {
    if (sending) return;
    sending = true;
    try {
      apply(await rpc('act', <String, dynamic>{'type': type, ...extra}));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    sending = false;
  }

  void fly(String icon, {bool big = false}) {
    if (!mounted || icon.isEmpty) return;
    final _Fly f = _Fly(key: ValueKey<int>(flyKey++), icon: icon, left: 0.08 + random.nextDouble() * 0.8, big: big, onDone: (Key k) {
      if (mounted) setState(() => flying.removeWhere((_Fly x) => x.key == k));
    });
    setState(() {
      flying.add(f);
      if (flying.length > 14) flying.removeAt(0);
    });
  }

  void apply(Map<String, dynamic> s) {
    if (!mounted || s['roster'] is! List) return;
    final bool live = yes(s['live']);
    final bool ended = yes(s['ended']);

    for (final Map<String, dynamic> e in rows(s['events'])) {
      final String type = str(e['type']);
      final String val = str(e['val']);
      if (type == 'react') {
        if (str(e['name']) != name) fly(reactionIcons[val] ?? '');
      } else if (type == 'star') {
        fly('⭐', big: true);
        toast(context, val == name && !host ? 'You earned a star! ⭐' : '$val earned a star ⭐');
      } else if (type == 'pick') {
        toast(context, '🎲 $val, it is your turn!');
      } else if (type == 'start') {
        toast(context, 'Class has started. Welcome! 👋');
      }
    }

    final Map<String, dynamic>? poll = asMap(s['poll']);
    if (poll != null && num0(poll['id']) != lastPollId) {
      lastPollId = num0(poll['id']);
      if (yes(poll['open']) && !host) {
        tabIndex = 1;
        toast(context, '❓ New question from your teacher');
      }
    }

    final int secs = num0(s['break']);
    if (secs > 0) {
      if (breakEnds == null) breakTip = _breakTips[random.nextInt(_breakTips.length)];
      breakEnds = DateTime.now().add(Duration(seconds: secs));
      tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (breakEnds != null && DateTime.now().isAfter(breakEnds!)) {
          breakEnds = null;
          tick?.cancel();
          tick = null;
          toast(context, 'Break is over. Welcome back! 🙌');
        }
        setState(() {});
      });
    } else if (breakEnds != null) {
      breakEnds = null;
      tick?.cancel();
      tick = null;
    }

    final int last = num0(s['last']);
    setState(() {
      room = s;
      if (last > 0) since = last;
    });

    if (wasLive && ended && !host && !asked) askFeedback(leaving: false);
    wasLive = live;
  }

  Future<void> askFeedback({required bool leaving}) async {
    if (host) {
      if (leaving) Navigator.of(context).pop();
      return;
    }
    asked = true;
    final bool? sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext sheet) => _FeedbackSheet(options: rows(info?['feedback']), onSend: (int vote, String reaction, String comment) => rpc('feedback', <String, dynamic>{'vote': vote, 'reaction': reaction, 'comment': comment})),
    );
    if (!mounted) return;
    if (sent == true) toast(context, 'Thank you! Your feedback helps make the next class better. 🎉');
    if (leaving) {
      joined = false;
      pollTimer?.cancel();
      AppScope.read(context).refreshMe();
      Navigator.of(context).pop();
    }
  }

  Future<void> newPoll() async {
    final Map<String, dynamic>? p = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _PollDialog());
    if (p == null) return;
    await act('poll', p);
    if (mounted) setState(() => tabIndex = 1);
  }

  // ---- building blocks ------------------------------------------------------

  Widget joinView() {
    final List<String> names = strings(info?['names']);
    final List<Map<String, dynamic>> moods = rows(info?['moods']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: <Widget>[
        Align(alignment: Alignment.centerLeft, child: Pill(host ? 'You are the teacher' : 'Live classroom', color: AB.tones[0])),
        const SizedBox(height: 10),
        Text(str(info?['title']), style: h1),
        const SizedBox(height: 4),
        Text(<String>[str(info?['teacher_name']), str(info?['schedule'])].where((String s) => s.isNotEmpty).join(' · '), style: mutedText),
        const SizedBox(height: 22),
        if (names.length > 1) ...<Widget>[
          const Text('Who is joining?', style: h2),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[for (final String n in names) ChoiceChip(label: Text(n), selected: name == n, onSelected: (_) => setState(() => name = n))]),
          const SizedBox(height: 20),
        ] else
          Padding(padding: const EdgeInsets.only(bottom: 20), child: Text('Joining as $name', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        if (!host && moods.isNotEmpty) ...<Widget>[
          const Text('How are you feeling today?', style: h2),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final Map<String, dynamic> m in moods)
                ChoiceChip(label: Text('${str(m['icon'])} ${str(m['label'])}'), selected: mood == str(m['key']), onSelected: (_) => setState(() => mood = str(m['key']))),
            ],
          ),
          const SizedBox(height: 24),
        ],
        FilledButton(onPressed: joining ? null : join, child: Text(joining ? 'Opening…' : (host ? 'Open the classroom' : 'Join the class'))),
        const SizedBox(height: 20),
        const Text('• Find a quiet spot and keep water nearby.\n• Allow the camera and microphone when asked.\n• Be kind. Everyone is here to learn.', style: mutedText),
      ],
    );
  }

  Widget peopleTab(List<Map<String, dynamic>> roster) {
    final List<Map<String, dynamic>> sorted = List<Map<String, dynamic>>.from(roster)
      ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final int h = num0(b['host']) - num0(a['host']);
        if (h != 0) return h;
        final int hand = num0(b['hand']) - num0(a['hand']);
        return hand != 0 ? hand : num0(b['stars']) - num0(a['stars']);
      });
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: <Widget>[
        for (final Map<String, dynamic> p in sorted)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: yes(p['hand']) ? const Color(0xFFFFEFC7) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: yes(p['me']) ? AB.sky : AB.line, width: yes(p['me']) ? 2 : 1),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(radius: 17, backgroundColor: AB.dusk, foregroundColor: Colors.white, child: Text(str(p['name'], '?').substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('${str(p['name'])}${yes(p['me']) ? ' (you)' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (yes(p['host'])) const Text('Teacher', style: TextStyle(fontSize: 12, color: AB.muted)) else if (host && str(p['mood']).isNotEmpty) Text('Feeling ${str(p['mood'])}', style: const TextStyle(fontSize: 12, color: AB.muted)),
                    ],
                  ),
                ),
                if (!yes(p['host'])) ...<Widget>[
                  if (yes(p['hand']))
                    host
                        ? IconButton(tooltip: 'Lower hand', onPressed: () => act('lower', <String, dynamic>{'tuid': num0(p['uid']), 'tname': str(p['name'])}), icon: const Text('✋', style: TextStyle(fontSize: 20)))
                        : const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('✋', style: TextStyle(fontSize: 20))),
                  Text('⭐ ${num0(p['stars'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (host)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12), side: const BorderSide(color: AB.line)),
                        onPressed: () => act('star', <String, dynamic>{'tuid': num0(p['uid']), 'tname': str(p['name'])}),
                        child: const Text('+⭐'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(host ? 'Tap +⭐ to reward a learner. Tap a raised hand to lower it.' : 'Stars come from your teacher for great effort, kind words and brave answers.', style: mutedText),
      ],
    );
  }

  Widget quizTab(Map<String, dynamic>? p) {
    if (p == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text('No question right now. When the teacher asks one, it shows up here.', style: mutedText),
          if (host) Padding(padding: const EdgeInsets.only(top: 14), child: OutlinedButton(onPressed: newPoll, child: const Text('Ask a quick question'))),
        ],
      );
    }
    final List<String> opts = strings(p['opts']);
    final List<int>? counts = p['counts'] is List ? (p['counts'] as List<dynamic>).map(num0).toList() : null;
    final int total = counts == null ? 0 : counts.fold<int>(0, (int a, int b) => a + b);
    final bool open = yes(p['open']);
    final int mine = p['mine'] == null ? -1 : num0(p['mine']);
    final int right = p['right'] == null ? -1 : num0(p['right']);
    String note;
    if (!open) {
      note = (right >= 0 && !host && mine >= 0) ? (mine == right ? '🎉 You got it right!' : 'Good try! The answer was ${String.fromCharCode(65 + right)}.') : 'Question closed.';
    } else if (host) {
      note = '$total answered so far.';
    } else {
      note = mine >= 0 ? 'Answer saved. You can change it until the teacher closes the question.' : 'Tap your answer.';
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(str(p['q']), style: h2),
        const SizedBox(height: 12),
        for (int i = 0; i < opts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: right == i ? AB.teal : (mine == i ? AB.sky : AB.line), width: (right == i || mine == i) ? 2 : 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: (open && !host) ? () => act('answer', <String, dynamic>{'ref': num0(p['id']), 'val': '$i'}) : null,
                child: Stack(
                  children: <Widget>[
                    if (counts != null && i < counts.length)
                      Positioned.fill(
                        child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: total == 0 ? 0.0 : counts[i] / total, child: const ColoredBox(color: Color(0x334C7DFF))),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(radius: 14, backgroundColor: right == i ? AB.teal : const Color(0xFFECEFF8), foregroundColor: right == i ? Colors.white : AB.dusk, child: Text(String.fromCharCode(65 + i), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                          const SizedBox(width: 10),
                          Expanded(child: Text(opts[i], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                          if (counts != null && i < counts.length) Text('${counts[i]}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Text(note, style: mutedText),
        if (host) ...<Widget>[
          const SizedBox(height: 12),
          if (open) OutlinedButton(onPressed: () => act('poll_close'), child: const Text('Close question and show the answer')) else OutlinedButton(onPressed: newPoll, child: const Text('Ask another question')),
        ],
      ],
    );
  }

  Widget toolsTab(bool live, List<Map<String, dynamic>> roster) {
    final List<Map<String, dynamic>> learners = roster.where((Map<String, dynamic> p) => !yes(p['host'])).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (!live) FilledButton(onPressed: () => act('start'), child: const Text('Start class')) else OutlinedButton(onPressed: () => act('end'), child: const Text('End class and ask for feedback')),
        const SizedBox(height: 18),
        const Text('Quick question', style: h2),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: newPoll, icon: const Icon(Icons.quiz_outlined), label: const Text('Ask the class')),
        const SizedBox(height: 18),
        const Text('Brain break', style: h2),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final int m in const <int>[1, 2, 3]) ActionChip(label: Text('$m min'), onPressed: () => act('break', <String, dynamic>{'val': '${m * 60}'})),
            ActionChip(label: const Text('Stop'), onPressed: () => act('break', <String, dynamic>{'val': '0'})),
          ],
        ),
        const SizedBox(height: 18),
        const Text('Pick a learner', style: h2),
        const SizedBox(height: 4),
        const Text('Chooses someone at random so everyone gets a turn.', style: mutedText),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            if (learners.isEmpty) {
              toast(context, 'No learners are here yet.');
              return;
            }
            final Map<String, dynamic> p = learners[random.nextInt(learners.length)];
            act('pick', <String, dynamic>{'tuid': num0(p['uid']), 'tname': str(p['name'])});
          },
          child: const Text('🎲 Pick someone'),
        ),
      ],
    );
  }

  Widget roomView() {
    final Map<String, dynamic> s = room ?? <String, dynamic>{};
    final List<Map<String, dynamic>> roster = rows(s['roster']);
    final bool live = yes(s['live']);
    final bool ended = yes(s['ended']);
    final Map<String, dynamic>? poll = asMap(s['poll']);
    Map<String, dynamic>? me;
    for (final Map<String, dynamic> p in roster) {
      if (yes(p['me'])) me = p;
    }
    final bool handUp = yes(me?['hand']);
    final int secondsLeft = breakEnds == null ? 0 : math.max(0, breakEnds!.difference(DateTime.now()).inSeconds);
    final List<String> tabs = <String>['People ${roster.length}', 'Quiz', if (host) 'Tools'];
    final int tab = math.min(tabIndex, tabs.length - 1);

    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: <Widget>[
                  Pill(live ? '● LIVE' : (ended ? 'Class has ended' : 'Waiting for the teacher'), color: live ? AB.red : const Color(0xFFECEFF8), textColor: live ? Colors.white : AB.muted),
                  const Spacer(),
                  if (!host) Pill('⭐ ${num0(me?['stars'])}', color: const Color(0xFFFFE9B8)),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: const Color(0xFF0B1126), borderRadius: BorderRadius.circular(22)),
              child: secondsLeft > 0
                  ? Column(
                      children: <Widget>[
                        const Text('🧘 Brain break!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(breakTip, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFC9D1EE))),
                        Text('${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}', style: const TextStyle(color: AB.sun, fontSize: 40, fontWeight: FontWeight.w800)),
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        const Text('🎥', style: TextStyle(fontSize: 30)),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('The video opens outside the app. Come back here for reactions, stars and quiz questions.', style: TextStyle(color: Color(0xFFC9D1EE), height: 1.35))),
                        const SizedBox(width: 8),
                        FilledButton(onPressed: videoUrl.isEmpty ? null : () => openLink(context, videoUrl), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), child: const Text('Open video')),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(label: Text(tabs[i]), selected: tab == i, onSelected: (_) => setState(() => tabIndex = i)),
                    ),
                ],
              ),
            ),
            Expanded(child: tab == 0 ? peopleTab(roster) : (tab == 1 ? quizTab(poll) : toolsTab(live, roster))),
            Container(
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AB.line))),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        for (final MapEntry<String, String> r in reactionIcons.entries)
                          IconButton(
                            onPressed: () {
                              if (DateTime.now().difference(lastReact).inMilliseconds < 900) return;
                              lastReact = DateTime.now();
                              fly(r.value);
                              act('react', <String, dynamic>{'val': r.key});
                            },
                            icon: Text(r.value, style: const TextStyle(fontSize: 26)),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: Row(
                        children: <Widget>[
                          if (!host) ...<Widget>[
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(backgroundColor: handUp ? AB.sun : Colors.white, side: BorderSide(color: handUp ? AB.sun : AB.line, width: 1.5), minimumSize: const Size(0, 46)),
                                onPressed: () => act('hand', <String, dynamic>{'val': handUp ? '' : '1'}),
                                child: Text(handUp ? '✋ Lower hand' : '✋ Raise hand'),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AB.red, foregroundColor: Colors.white, minimumSize: const Size(0, 46)),
                              onPressed: () => askFeedback(leaving: true),
                              child: const Text('Leave'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned.fill(child: IgnorePointer(child: Stack(children: List<Widget>.of(flying)))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loadError != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[Text(loadError!, textAlign: TextAlign.center, style: mutedText), const SizedBox(height: 16), OutlinedButton(onPressed: loadInfo, child: const Text('Try again'))]),
        ),
      );
    } else if (info == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = joined ? roomView() : joinView();
    }
    return Scaffold(
      appBar: AppBar(title: Text(joined ? str(info?['title'], 'Classroom') : 'Classroom', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: body,
    );
  }
}

/// One emoji floating up the screen.
class _Fly extends StatelessWidget {
  const _Fly({required Key key, required this.icon, required this.left, required this.big, required this.onDone}) : super(key: key);
  final String icon;
  final double left;
  final bool big;
  final void Function(Key key) onDone;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2800),
      onEnd: () => onDone(key!),
      builder: (BuildContext context, double t, Widget? child) {
        return Align(
          alignment: Alignment(left * 2 - 1, 0.7 - t * 1.5),
          child: Opacity(opacity: t < 0.1 ? t * 10 : (1 - t).clamp(0.0, 1.0).toDouble(), child: child),
        );
      },
      child: Text(icon, style: TextStyle(fontSize: big ? 46 : 32)),
    );
  }
}

class _PollDialog extends StatefulWidget {
  const _PollDialog();

  @override
  State<_PollDialog> createState() => _PollDialogState();
}

class _PollDialogState extends State<_PollDialog> {
  final TextEditingController q = TextEditingController();
  final List<TextEditingController> o = List<TextEditingController>.generate(4, (_) => TextEditingController());
  int right = 0;
  String? error;

  @override
  void dispose() {
    q.dispose();
    for (final TextEditingController c in o) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ask a quick question'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(controller: q, maxLength: 160, decoration: const InputDecoration(labelText: 'Question', hintText: 'What is 7 × 8?', counterText: '')),
            for (int i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(controller: o[i], maxLength: 60, decoration: InputDecoration(labelText: 'Answer ${String.fromCharCode(65 + i)}${i > 1 ? ' (optional)' : ''}', counterText: '')),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: right,
              decoration: const InputDecoration(labelText: 'Right answer'),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 0, child: Text('No right answer (opinion)')),
                DropdownMenuItem<int>(value: 1, child: Text('A')),
                DropdownMenuItem<int>(value: 2, child: Text('B')),
                DropdownMenuItem<int>(value: 3, child: Text('C')),
                DropdownMenuItem<int>(value: 4, child: Text('D')),
              ],
              onChanged: (int? v) => setState(() => right = v ?? 0),
            ),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: AB.red))),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final List<String> opts = o.map((TextEditingController c) => c.text.trim()).where((String s) => s.isNotEmpty).toList();
            if (q.text.trim().isEmpty || opts.length < 2) {
              setState(() => error = 'Write a question and at least two answers.');
              return;
            }
            if (right > opts.length) {
              setState(() => error = 'The right answer must be one of the answers you wrote.');
              return;
            }
            Navigator.pop(context, <String, dynamic>{'q': q.text.trim(), 'opts': opts, 'right': right});
          },
          child: const Text('Send to class'),
        ),
      ],
    );
  }
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.options, required this.onSend});
  final List<Map<String, dynamic>> options;
  final Future<Map<String, dynamic>> Function(int vote, String reaction, String comment) onSend;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final TextEditingController comment = TextEditingController();
  int vote = 0;
  String reaction = '';
  bool busy = false;

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Widget voteButton(int value, String icon, String label, Color color) {
    final bool on = vote == value;
    return Expanded(
      child: Material(
        color: on ? color.withAlpha(40) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: on ? color : AB.line, width: 2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => vote = on ? 0 : value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: <Widget>[Text(icon, style: const TextStyle(fontSize: 34)), Text(label, style: const TextStyle(fontWeight: FontWeight.w700))]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 22, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text("How was today's class?", style: h1),
            const SizedBox(height: 4),
            const Text('🔒 Anonymous. Your name is not saved with your answer.', style: mutedText),
            const SizedBox(height: 16),
            Row(children: <Widget>[voteButton(1, '👍', 'I liked it', AB.teal), const SizedBox(width: 10), voteButton(-1, '👎', 'Not for me', AB.coral)]),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final Map<String, dynamic> r in widget.options)
                  ChoiceChip(label: Text('${str(r['icon'])} ${str(r['label'])}'), selected: reaction == str(r['key']), onSelected: (bool on) => setState(() => reaction = on ? str(r['key']) : '')),
              ],
            ),
            const SizedBox(height: 14),
            TextField(controller: comment, maxLines: 3, maxLength: 600, decoration: const InputDecoration(labelText: 'Anything you want to tell us? (optional)', hintText: 'What was the best part? What was hard?', counterText: '')),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(child: OutlinedButton(onPressed: busy ? null : () => Navigator.pop(context, false), child: const Text('Skip'))),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() => busy = true);
                            bool ok = true;
                            try {
                              await widget.onSend(vote, reaction, comment.text.trim());
                            } on ApiException {
                              ok = false;
                            }
                            if (context.mounted) Navigator.pop(context, ok);
                          },
                    child: const Text('Send feedback'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController search = TextEditingController();
  Timer? debounce;
  Map<String, String> filters = <String, String>{};
  List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
  int page = 1, pages = 1, total = 0, seenVersion = -1, request = 0;
  bool busy = false;
  String? error;

  static const Map<String, String> trackNames = <String, String>{
    'homeschool-academics': 'Homeschool',
    'tutoring': 'Tutoring',
    'leadership': 'Leadership',
    'enrichment': 'Enrichment',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppState app = AppScope.of(context);
    if (app.exploreVersion != seenVersion) {
      seenVersion = app.exploreVersion;
      filters = Map<String, String>.from(app.exploreFilters);
      search.text = '';
      WidgetsBinding.instance.addPostFrameCallback((_) => load(reset: true));
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool reset = false}) async {
    if (!mounted) return;
    final int mine = ++request;
    final int want = reset ? 1 : page + 1;
    setState(() {
      busy = true;
      error = null;
      if (reset) items = <Map<String, dynamic>>[];
    });
    try {
      final Map<String, dynamic> d = await AppScope.read(context).api.get('/classes', <String, String>{...filters, 'q': search.text.trim(), 'page': '$want'});
      if (!mounted || mine != request) return;
      setState(() {
        items = <Map<String, dynamic>>[...items, ...rows(d['items'])];
        page = want;
        pages = num0(d['pages']);
        total = num0(d['total']);
        busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted || mine != request) return;
      setState(() {
        error = e.message;
        busy = false;
      });
    }
  }

  void setFilter(String key, String? value) {
    setState(() {
      if (value == null || value.isEmpty || filters[key] == value) {
        filters.remove(key);
      } else {
        filters[key] = value;
      }
    });
    load(reset: true);
  }

  Widget chip(String key, String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(label: Text(label), selected: filters[key] == value, onSelected: (_) => setFilter(key, value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String age = filters['age'] ?? '';
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(hintText: 'Search classes and tutors', prefixIcon: Icon(Icons.search)),
            onSubmitted: (_) => load(reset: true),
            onChanged: (_) {
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 500), () => load(reset: true));
            },
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InputChip(
                  label: Text(age.isEmpty ? 'Any age' : 'Age $age'),
                  selected: age.isNotEmpty,
                  onPressed: () async {
                    final String? picked = await showModalBottomSheet<String>(
                      context: context,
                      builder: (BuildContext sheet) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              ActionChip(label: const Text('Any age'), onPressed: () => Navigator.pop(sheet, '')),
                              for (int a = 3; a <= 18; a++) ActionChip(label: Text('$a'), onPressed: () => Navigator.pop(sheet, '$a')),
                            ],
                          ),
                        ),
                      ),
                    );
                    if (picked == null) return;
                    setState(() {
                      if (picked.isEmpty) {
                        filters.remove('age');
                      } else {
                        filters['age'] = picked;
                      }
                    });
                    load(reset: true);
                  },
                ),
              ),
              chip('format', 'group', 'Group classes'),
              chip('format', 'one_to_one', '1:1 tutoring'),
              for (final MapEntry<String, String> t in trackNames.entries) chip('track', t.key, t.value),
              if (filters.containsKey('subj')) Padding(padding: const EdgeInsets.only(right: 8), child: InputChip(label: Text('Subject: ${filters['subj']}'), onDeleted: () => setFilter('subj', null))),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => load(reset: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                if (error != null)
                  Panel(child: Column(children: <Widget>[Text(error!, style: mutedText), const SizedBox(height: 10), OutlinedButton(onPressed: () => load(reset: true), child: const Text('Try again'))]))
                else if (!busy && items.isEmpty)
                  const Panel(child: Text('No classes match these filters yet. Try removing one.', style: mutedText))
                else if (items.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(total == 1 ? '1 class' : '$total classes', style: mutedText)),
                for (final Map<String, dynamic> c in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: ClassCard(c)),
                if (busy) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                if (!busy && error == null && page < pages) OutlinedButton(onPressed: () => load(), child: const Text('Show more')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

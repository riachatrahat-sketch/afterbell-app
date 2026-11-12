import 'package:flutter/material.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'teaching.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    return app.signedIn ? _Account(app: app) : const AuthForm();
  }
}

class AuthForm extends StatefulWidget {
  const AuthForm({super.key});

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final GlobalKey<FormState> form = GlobalKey<FormState>();
  final TextEditingController name = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  bool joining = false, busy = false, hide = true;
  String? error;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !(form.currentState?.validate() ?? false)) return;
    setState(() {
      busy = true;
      error = null;
    });
    final AppState app = AppScope.read(context);
    try {
      if (joining) {
        await app.signup(name.text, email.text, password.text);
      } else {
        await app.login(email.text, password.text);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: <Widget>[
        Text(joining ? 'Join Afterbell for free' : 'Welcome back', style: h1),
        const SizedBox(height: 6),
        Text(joining ? 'Accounts are for parents and guardians. You add your learners after joining.' : 'Log in with the email and password of your Afterbell account.', style: mutedText),
        const SizedBox(height: 20),
        Form(
          key: form,
          child: AutofillGroup(
            child: Column(
              children: <Widget>[
                if (joining) ...<Widget>[
                  TextFormField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const <String>[AutofillHints.name],
                    decoration: const InputDecoration(labelText: 'Your name'),
                    validator: (String? v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const <String>[AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (String? v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  obscureText: hide,
                  autofillHints: <String>[joining ? AutofillHints.newPassword : AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: joining ? 'At least 8 characters' : null,
                    suffixIcon: IconButton(tooltip: hide ? 'Show password' : 'Hide password', icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => hide = !hide)),
                  ),
                  validator: (String? v) => (v ?? '').length < (joining ? 8 : 1) ? (joining ? 'Use at least 8 characters' : 'Enter your password') : null,
                  onFieldSubmitted: (_) => submit(),
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...<Widget>[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: AB.red, fontWeight: FontWeight.w600))],
        const SizedBox(height: 18),
        FilledButton(onPressed: busy ? null : submit, child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Text(joining ? 'Create account' : 'Log in')),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : () => setState(() {
                joining = !joining;
                error = null;
              }),
          child: Text(joining ? 'I already have an account' : 'New here? Join for free'),
        ),
      ],
    );
  }
}

class _Account extends StatelessWidget {
  const _Account({required this.app});
  final AppState app;

  Future<void> addLearner(BuildContext context) async {
    final TextEditingController name = TextEditingController();
    final TextEditingController age = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: const Text('Add a learner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'First name or nickname')),
            const SizedBox(height: 12),
            TextField(controller: age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age (3 to 18)')),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await app.learner(<String, dynamic>{'op': 'add', 'name': name.text.trim(), 'age': int.tryParse(age.text.trim()) ?? 0});
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  Future<void> removeLearner(BuildContext context, Map<String, dynamic> l) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text('Remove ${str(l['name'])}?'),
        content: const Text('The learner profile is removed from your account. Stars already earned stay in the class records.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await app.learner(<String, dynamic>{'op': 'remove', 'index': num0(l['index'])});
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> u = app.user ?? <String, dynamic>{};
    final List<Map<String, dynamic>> learners = rows(u['learners']);
    return RefreshIndicator(
      onRefresh: app.refreshMe,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Text('Hi, ${str(u['name'], 'there')}', style: h1),
          Text(str(u['email']), style: mutedText),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              const Expanded(child: Text('Learners', style: h2)),
              TextButton.icon(onPressed: () => addLearner(context), icon: const Icon(Icons.add), label: const Text('Add')),
            ],
          ),
          if (learners.isEmpty) const Panel(child: Text('Add your child so they can join live classes and collect stars.', style: mutedText)),
          for (final Map<String, dynamic> l in learners)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                color: const Color(0xFFFFF6E0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: Text(str(l['name']), style: h2)),
                        IconButton(tooltip: 'Remove learner', icon: const Icon(Icons.close, size: 20), onPressed: () => removeLearner(context, l)),
                      ],
                    ),
                    Text('⭐ ${num0(l['stars'])} stars   ·   ${num0(l['sessions'])} classes attended', style: const TextStyle(fontWeight: FontWeight.w700, color: AB.dusk)),
                    if (rows(l['badges']).isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: <Widget>[for (final Map<String, dynamic> b in rows(l['badges'])) Pill('${str(b['icon'])} ${str(b['label'])}')]),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                ListTile(leading: const Icon(Icons.videocam_outlined), title: const Text('Live classroom'), trailing: const Icon(Icons.chevron_right), onTap: () => app.goTab(2)),
                const Divider(height: 1, color: AB.line),
                ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: const Text('Favorites'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FavoritesScreen())),
                ),
                if (app.isTeacher) ...<Widget>[
                  const Divider(height: 1, color: AB.line),
                  ListTile(
                    leading: const Icon(Icons.insights_outlined),
                    title: const Text('My teaching'),
                    subtitle: const Text('Attendance and anonymous feedback'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TeachingScreen())),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: app.logout, child: const Text('Log out')),
        ],
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: Loader(
        load: () => app.api.get('/me/favorites'),
        builder: (BuildContext context, Map<String, dynamic> d, Future<void> Function() reload) {
          final List<Map<String, dynamic>> items = rows(d['items']).where((Map<String, dynamic> c) => app.isFav(num0(c['id']))).toList();
          if (items.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No favorites yet. Tap the heart on a class to save it.', textAlign: TextAlign.center, style: mutedText)));
          return ListView(padding: const EdgeInsets.all(16), children: <Widget>[for (final Map<String, dynamic> c in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: ClassCard(c))]);
        },
      ),
    );
  }
}

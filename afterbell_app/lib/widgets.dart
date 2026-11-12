import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/class_detail.dart';
import 'state.dart';
import 'theme.dart';

void toast(BuildContext context, String message) {
  final ScaffoldMessengerState? m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(content: Text(message)));
}

/// Shows a spinner, an error with a retry button, or the loaded content.
class Loader extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});
  final Future<Map<String, dynamic>> Function() load;
  final Widget Function(BuildContext context, Map<String, dynamic> data, Future<void> Function() reload) builder;

  @override
  State<Loader> createState() => LoaderState();
}

class LoaderState extends State<Loader> {
  Map<String, dynamic>? data;
  String? error;
  bool busy = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (mounted) {
      setState(() {
        busy = true;
        error = null;
      });
    }
    try {
      final Map<String, dynamic> d = await widget.load();
      if (!mounted) return;
      setState(() {
        data = d;
        busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.signedOut) AppScope.read(context).sessionEnded();
      setState(() {
        error = e.message;
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data != null) return widget.builder(context, data!, reload);
    if (busy) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 44, color: AB.muted),
            const SizedBox(height: 12),
            Text(error ?? 'Something went wrong.', textAlign: TextAlign.center, style: mutedText),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: reload, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = Colors.white, this.textColor = AB.dusk});
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color = Colors.white});
  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), border: Border.all(color: AB.line)),
      child: child,
    );
  }
}

IconData subjectIcon(String slug) {
  switch (slug) {
    case 'math':
      return Icons.calculate_outlined;
    case 'english':
      return Icons.menu_book_outlined;
    case 'science':
      return Icons.science_outlined;
    case 'social-studies':
      return Icons.public_outlined;
    case 'languages':
      return Icons.translate_outlined;
    case 'coding':
      return Icons.code_outlined;
    case 'speaking':
      return Icons.record_voice_over_outlined;
    case 'business':
      return Icons.lightbulb_outline;
    case 'logic':
      return Icons.extension_outlined;
    default:
      return Icons.school_outlined;
  }
}

class FavButton extends StatelessWidget {
  const FavButton({super.key, required this.id, this.onDark = false});
  final int id;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final bool on = app.isFav(id);
    return IconButton(
      tooltip: on ? 'Remove from favorites' : 'Save to favorites',
      icon: Icon(on ? Icons.favorite : Icons.favorite_border, color: on ? AB.coral : (onDark ? Colors.white : AB.dusk)),
      onPressed: () async {
        if (!app.signedIn) {
          toast(context, 'Log in to save favorites.');
          app.goTab(3);
          return;
        }
        try {
          await app.toggleFav(id);
        } on ApiException catch (e) {
          if (context.mounted) toast(context, e.message);
        }
      },
    );
  }
}

class ClassCard extends StatelessWidget {
  const ClassCard(this.c, {super.key, this.width});
  final Map<String, dynamic> c;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final int id = num0(c['id']);
    final bool one = yes(c['one_to_one']);
    final Map<String, dynamic>? subject = asMap(c['subject']);
    final String image = str(c['image']);
    final Color tone = AB.tones[num0(c['tone']) % AB.tones.length];
    final String teacher = str(c['teacher_name']);

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AB.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ClassDetailScreen(id: id, title: str(c['title'])))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 104,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (image.isNotEmpty)
                      Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: tone))
                    else
                      ColoredBox(color: tone, child: Icon(subjectIcon(str(subject?['slug'])), size: 46, color: AB.dusk.withAlpha(150))),
                    Positioned(left: 10, top: 10, child: Pill(one ? '1:1 tutoring' : 'Live group', color: one ? AB.sky : AB.dusk, textColor: Colors.white)),
                    Positioned(right: 0, top: 0, child: FavButton(id: id)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(str(c['title']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, height: 1.2, fontWeight: FontWeight.w800, color: AB.dusk)),
                    const SizedBox(height: 6),
                    Text(<String>[str(c['age']), str(c['schedule'])].where((String s) => s.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mutedText),
                    if (teacher.isNotEmpty) Text(teacher, maxLines: 1, overflow: TextOverflow.ellipsis, style: mutedText),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(text: str(c['price']), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AB.dusk)),
                          TextSpan(text: '  ${str(c['price_unit'])}', style: const TextStyle(fontSize: 12, color: AB.muted)),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A friendly prompt for screens that need an account.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.lock_outline, size: 44, color: AB.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: mutedText),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => AppScope.read(context).goTab(3), child: const Text('Log in or join for free')),
          ],
        ),
      ),
    );
  }
}

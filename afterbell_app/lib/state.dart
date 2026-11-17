import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Signed-in user, favorites and the API client, shared by every screen.
class AppState extends ChangeNotifier {
  final Api api = Api();
  Map<String, dynamic>? user;
  bool booting = true;

  /// Bottom tab the shell should show. Screens change it to jump between tabs.
  int tab = 0;

  /// Filters handed from the home screen to the explore tab.
  Map<String, String> exploreFilters = <String, String>{};
  int exploreVersion = 0;

  bool get signedIn => user != null;
  bool get isTeacher => yes(user?['is_teacher']);
  bool get isTeacherAccount => str(user?['type']) == 'teacher';
  int get unreadNotices => num0(user?['unread_notices']);
  int get unreadSupport => num0(user?['unread_support']);
  List<int> get favorites => (user?['favorites'] is List) ? (user!['favorites'] as List<dynamic>).map(num0).toList() : <int>[];
  bool isFav(int id) => favorites.contains(id);

  Future<void> boot() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('token');
    if (saved != null && saved.isNotEmpty) {
      api.token = saved;
      try {
        user = await api.get('/me');
      } on ApiException catch (e) {
        if (e.signedOut) await _forget();
      }
    }
    booting = false;
    notifyListeners();
  }

  Future<void> _remember(Map<String, dynamic> res) async {
    api.token = str(res['token']);
    user = asMap(res['user']);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', api.token ?? '');
    notifyListeners();
  }

  Future<void> _forget() async {
    api.token = null;
    user = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<void> login(String email, String password) async {
    await _remember(await api.post('/auth/login', <String, dynamic>{'email': email.trim(), 'password': password}));
  }

  /// Returns a message when the account must wait for admin approval (no sign-in yet), or null when signed in.
  Future<String?> signup(String name, String email, String password, {String type = 'student', String subject = '', String about = ''}) async {
    final Map<String, dynamic> res = await api.post('/auth/signup', <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'type': type,
      if (subject.trim().isNotEmpty) 'subject': subject.trim(),
      if (about.trim().isNotEmpty) 'about': about.trim(),
    });
    if (yes(res['pending'])) return str(res['message'], 'Your request was sent. We will email you once it is approved.');
    await _remember(res);
    return null;
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout', <String, dynamic>{});
    } on ApiException {
      // Signing out on this phone still works without a connection.
    }
    await _forget();
    notifyListeners();
  }

  /// Call when any request says the session ended.
  Future<void> sessionEnded() async {
    await _forget();
    notifyListeners();
  }

  Future<void> refreshMe() async {
    if (!signedIn) return;
    try {
      user = await api.get('/me');
      notifyListeners();
    } on ApiException catch (e) {
      if (e.signedOut) await sessionEnded();
    }
  }

  Future<void> toggleFav(int id) async {
    final Map<String, dynamic> res = await api.post('/me/favorites', <String, dynamic>{'id': id});
    user = <String, dynamic>{...?user, 'favorites': res['favorites']};
    notifyListeners();
  }

  Future<void> learner(Map<String, dynamic> body) async {
    user = await api.post('/me/learners', body);
    notifyListeners();
  }

  void goTab(int index) {
    tab = index;
    notifyListeners();
  }

  void explore(Map<String, String> filters) {
    exploreFilters = filters;
    exploreVersion++;
    tab = 1;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }

  /// Use inside callbacks, where the widget should not rebuild on changes.
  static AppState read(BuildContext context) {
    final AppScope? scope = context.getInheritedWidgetOfExactType<AppScope>();
    return scope!.notifier!;
  }
}

import 'package:flutter/material.dart';

import 'screens/account.dart';
import 'screens/classrooms.dart';
import 'screens/explore.dart';
import 'screens/home.dart';
import 'state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AfterbellApp());
}

class AfterbellApp extends StatefulWidget {
  const AfterbellApp({super.key});

  @override
  State<AfterbellApp> createState() => _AfterbellAppState();
}

class _AfterbellAppState extends State<AfterbellApp> {
  final AppState state = AppState();

  @override
  void initState() {
    super.initState();
    state.boot();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Afterbell Academy',
        debugShowCheckedModeBanner: false,
        theme: AB.theme(),
        home: const Shell(),
      ),
    );
  }
}

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    if (app.booting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.notifications_active, size: 56, color: AB.sun),
              SizedBox(height: 12),
              Text('Afterbell Academy', style: h1),
              SizedBox(height: 20),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: app.tab,
          children: const <Widget>[HomeScreen(), ExploreScreen(), ClassroomsScreen(), AccountScreen()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: app.tab,
        onDestinationSelected: app.goTab,
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.videocam_outlined), selectedIcon: Icon(Icons.videocam), label: 'Classroom'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}

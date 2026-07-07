import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ola_tile_proxy.dart';

import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/group_provider.dart';
import 'providers/navigation_provider.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/group/create_group_screen.dart';
import 'screens/group/join_group_screen.dart';
import 'screens/group/group_lobby_screen.dart';
import 'screens/navigation/live_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OlaTileProxy.start();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: const TrailMateApp(),
    ),
  );
}

class TrailMateApp extends StatelessWidget {
  const TrailMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrailMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/create-group':
            return MaterialPageRoute(builder: (_) => const CreateGroupScreen());
          case '/join-group':
            return MaterialPageRoute(builder: (_) => const JoinGroupScreen());
          case '/group-lobby':
            final groupId = settings.arguments as String;
            return MaterialPageRoute(builder: (_) => GroupLobbyScreen(groupId: groupId));
          case '/live-navigation':
            final groupId = settings.arguments as String;
            return MaterialPageRoute(builder: (_) => LiveNavigationScreen(groupId: groupId));
          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Page not found')),
              ),
            );
        }
      },
    );
  }
}

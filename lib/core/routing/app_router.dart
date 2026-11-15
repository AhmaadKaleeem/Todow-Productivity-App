import 'package:flutter/material.dart';
import 'package:todow/bootstrap.dart';
import 'package:todow/presentation/app.dart';
import 'package:todow/presentation/shared/splash_screen.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
}

abstract final class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings, AppServices services) {
    switch (settings.name) {
      case AppRoutes.home:
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => AppShell(services: services),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        );
      case AppRoutes.splash:
      default:
        return MaterialPageRoute(
          builder: (_) => SplashScreen(services: services),
        );
    }
  }
}


import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/news_feed_screen.dart';
import 'screens/onboarding_choice_screen.dart';
import 'services/session_service.dart';
import 'widgets/curatx_logo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CuratXApp());
}

class CuratXApp extends StatelessWidget {
  const CuratXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CuratX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFDF7357),
          primary: const Color(0xFFDF7357),
          surface: const Color(0xFFFAFAFA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      ),
      home: const _SplashRouter(),
    );
  }
}

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _routeUser();
  }

  Future<void> _routeUser() async {
    await Future.delayed(const Duration(milliseconds: 900));
    final userId = await SessionService.getUserId();
    final hasOnboarded = await SessionService.getHasOnboarded();

    if (!mounted) return;

    Widget target;
    if (userId != null && userId.isNotEmpty) {
      target = hasOnboarded
          ? const NewsFeedScreen()
          : const OnboardingChoiceScreen();
    } else {
      target = const AuthScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CuratXLogo(size: 64),
            SizedBox(height: 16),
            Text(
              'AI-Curated News, Tailored to You',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFDF7357),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
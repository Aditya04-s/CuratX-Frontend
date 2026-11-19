import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/news_feed_screen.dart';
import 'screens/resume_upload_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final resumeStepCompleted =
      prefs.getBool('resume_step_completed') ?? false;

  runApp(MyApp(
    resumeStepCompleted: resumeStepCompleted,
  ));
}

class MyApp extends StatelessWidget {
  final bool resumeStepCompleted;

  const MyApp({
    super.key,
    this.resumeStepCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CuratX',
      theme: ThemeData(
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: resumeStepCompleted
          ? const NewsFeedScreen()
          : const ResumeUploadPage(),
    );
  }
}

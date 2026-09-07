import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

class NewittApp extends StatelessWidget {
  const NewittApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NEWITT Media Control Room',
      theme: AppTheme.dark,
      home: home,
    );
  }
}

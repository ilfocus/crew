// crew_gui/lib/app.dart
import 'package:flutter/material.dart';

class CrewApp extends StatelessWidget {
  final Widget home;
  const CrewApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crew',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: home,
    );
  }
}
